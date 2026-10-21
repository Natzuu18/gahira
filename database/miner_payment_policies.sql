-- Allow miners to submit and view their own service payments under RLS.
-- Admins can continue recording payments on behalf of service participants.

CREATE OR REPLACE FUNCTION public.is_service_billing_participant(
  target_service_request_id uuid,
  target_user_id uuid
)
RETURNS boolean
LANGUAGE sql
STABLE
SECURITY DEFINER
SET search_path = public
AS $$
  SELECT EXISTS (
    SELECT 1
    FROM public.service_requests AS request
    WHERE request.service_request_id = target_service_request_id
      AND (
        request.user_id = target_user_id
        OR target_user_id = ANY(
          COALESCE(request.participating_miners, '{}'::uuid[])
        )
        OR EXISTS (
          SELECT 1
          FROM public.service_participant_financials AS participant
          WHERE participant.service_request_id = target_service_request_id
            AND participant.user_id = target_user_id
        )
      )
  );
$$;

CREATE OR REPLACE FUNCTION public.can_manage_service_billing()
RETURNS boolean
LANGUAGE sql
STABLE
SECURITY DEFINER
SET search_path = public
AS $$
  SELECT EXISTS (
    SELECT 1
    FROM public.users AS account
    JOIN public.role AS account_role
      ON account_role.role_id = account.role_id
    WHERE account."userId" = auth.uid()
      AND lower(account_role.role) = 'admin'
      AND lower(account.status) IN ('active', 'approved')
  );
$$;

REVOKE ALL ON FUNCTION public.is_service_billing_participant(uuid, uuid)
  FROM PUBLIC;
REVOKE ALL ON FUNCTION public.can_manage_service_billing() FROM PUBLIC;
GRANT EXECUTE ON FUNCTION public.is_service_billing_participant(uuid, uuid)
  TO authenticated;
GRANT EXECUTE ON FUNCTION public.can_manage_service_billing() TO authenticated;

ALTER TABLE public.participant_payments ENABLE ROW LEVEL SECURITY;

ALTER TABLE public.participant_payments
  ADD COLUMN IF NOT EXISTS verification_status text NOT NULL DEFAULT 'approved',
  ADD COLUMN IF NOT EXISTS reviewed_by uuid REFERENCES public.users("userId"),
  ADD COLUMN IF NOT EXISTS reviewed_at timestamptz,
  ADD COLUMN IF NOT EXISTS review_note text;

CREATE INDEX IF NOT EXISTS participant_payments_pending_review_idx
  ON public.participant_payments(verification_status, payment_date);

DROP POLICY IF EXISTS participant_payments_read_own_or_admin
  ON public.participant_payments;
CREATE POLICY participant_payments_read_own_or_admin
  ON public.participant_payments
  FOR SELECT
  TO authenticated
  USING (
    user_id = auth.uid()
    OR public.can_manage_service_billing()
  );

DROP POLICY IF EXISTS participant_payments_insert_own_or_admin
  ON public.participant_payments;
CREATE POLICY participant_payments_insert_own_or_admin
  ON public.participant_payments
  FOR INSERT
  TO authenticated
  WITH CHECK (
    (
      user_id = auth.uid()
      AND recorded_by = auth.uid()
      AND public.is_service_billing_participant(service_request_id, auth.uid())
    )
    OR (
      public.can_manage_service_billing()
      AND recorded_by = auth.uid()
      AND public.is_service_billing_participant(service_request_id, user_id)
    )
  );

GRANT SELECT, INSERT ON public.participant_payments TO authenticated;

CREATE OR REPLACE FUNCTION public.submit_individual_service_payment(
  target_service_request_id uuid,
  payment_amount numeric,
  target_receipt_url text
)
RETURNS void
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  request public.service_requests%ROWTYPE;
  pending_total numeric;
  remaining numeric;
BEGIN
  IF auth.uid() IS NULL THEN
    RAISE EXCEPTION 'You must be signed in to pay this bill.';
  END IF;
  IF payment_amount IS NULL OR payment_amount <= 0 OR
      target_receipt_url IS NULL OR btrim(target_receipt_url) = '' THEN
    RAISE EXCEPTION 'Enter a valid amount and upload a receipt.';
  END IF;

  SELECT * INTO request
    FROM public.service_requests
    WHERE service_request_id = target_service_request_id
    FOR UPDATE;
  IF NOT FOUND OR request.user_id <> auth.uid() THEN
    RAISE EXCEPTION 'You are not authorized to pay this service bill.';
  END IF;

  SELECT COALESCE(SUM(payment.amount), 0)
    INTO pending_total
    FROM public.participant_payments AS payment
    WHERE payment.service_request_id = target_service_request_id
      AND payment.user_id = auth.uid()
      AND payment.verification_status = 'pending';
  remaining := greatest(
    0,
    COALESCE(request.total_bill, 0) - COALESCE(request.payment_amount, 0) - pending_total
  );
  IF payment_amount > remaining THEN
    RAISE EXCEPTION 'Payment exceeds your remaining unsubmitted balance of %.', remaining;
  END IF;

  INSERT INTO public.participant_payments (
    service_request_id,
    user_id,
    amount,
    receipt_url,
    payment_date,
    recorded_by,
    verification_status
  ) VALUES (
    target_service_request_id,
    auth.uid(),
    payment_amount,
    target_receipt_url,
    now(),
    auth.uid(),
    'pending'
  );
END;
$$;

REVOKE ALL ON FUNCTION public.submit_individual_service_payment(uuid, numeric, text)
  FROM PUBLIC;
GRANT EXECUTE ON FUNCTION public.submit_individual_service_payment(uuid, numeric, text)
  TO authenticated;

-- Participant balances are visible to their owner; only admins can create
-- or edit the group bill breakdown. Miner payments update balances via RPC.
ALTER TABLE public.service_participant_financials ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS service_participant_financials_read_own_or_admin
  ON public.service_participant_financials;
CREATE POLICY service_participant_financials_read_own_or_admin
  ON public.service_participant_financials
  FOR SELECT
  TO authenticated
  USING (
    user_id = auth.uid()
    OR public.can_manage_service_billing()
  );

DROP POLICY IF EXISTS service_participant_financials_admin_insert
  ON public.service_participant_financials;
CREATE POLICY service_participant_financials_admin_insert
  ON public.service_participant_financials
  FOR INSERT
  TO authenticated
  WITH CHECK (public.can_manage_service_billing());

DROP POLICY IF EXISTS service_participant_financials_admin_update
  ON public.service_participant_financials;
CREATE POLICY service_participant_financials_admin_update
  ON public.service_participant_financials
  FOR UPDATE
  TO authenticated
  USING (public.can_manage_service_billing())
  WITH CHECK (public.can_manage_service_billing());

GRANT SELECT, INSERT, UPDATE ON public.service_participant_financials
  TO authenticated;

CREATE OR REPLACE FUNCTION public.submit_group_service_payment(
  target_service_request_id uuid,
  payment_amount numeric,
  target_receipt_url text
)
RETURNS void
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  participant public.service_participant_financials%ROWTYPE;
  remaining numeric;
  pending_total numeric;
BEGIN
  IF auth.uid() IS NULL THEN
    RAISE EXCEPTION 'You must be signed in to pay this bill.';
  END IF;
  IF payment_amount IS NULL OR payment_amount <= 0 OR
      target_receipt_url IS NULL OR btrim(target_receipt_url) = '' THEN
    RAISE EXCEPTION 'Enter a valid amount and upload a receipt.';
  END IF;
  IF NOT public.is_service_billing_participant(
    target_service_request_id,
    auth.uid()
  ) THEN
    RAISE EXCEPTION 'You are not a participant in this service.';
  END IF;

  -- Serialize payments for this group so concurrent final payments cannot
  -- both miss the fact that the other participant has just paid.
  PERFORM 1
    FROM public.service_requests AS request
    WHERE request.service_request_id = target_service_request_id
    FOR UPDATE;

  SELECT *
    INTO participant
    FROM public.service_participant_financials AS financial
    WHERE financial.service_request_id = target_service_request_id
      AND financial.user_id = auth.uid()
    FOR UPDATE;

  IF NOT FOUND THEN
    RAISE EXCEPTION 'Your group bill is not available yet.';
  END IF;

  SELECT COALESCE(SUM(payment.amount), 0)
    INTO pending_total
    FROM public.participant_payments AS payment
    WHERE payment.service_request_id = target_service_request_id
      AND payment.user_id = auth.uid()
      AND payment.verification_status = 'pending';

  remaining := greatest(
    0,
    participant.total_due - participant.amount_paid - pending_total
  );
  IF payment_amount > remaining THEN
    RAISE EXCEPTION 'Payment exceeds your remaining unsubmitted balance of %.', remaining;
  END IF;

  INSERT INTO public.participant_payments (
    participant_financial_id,
    service_request_id,
    user_id,
    amount,
    receipt_url,
    payment_date,
    recorded_by,
    verification_status
  ) VALUES (
    participant.participant_financial_id,
    target_service_request_id,
    auth.uid(),
    payment_amount,
    target_receipt_url,
    now(),
    auth.uid(),
    'pending'
  );
END;
$$;

REVOKE ALL ON FUNCTION public.submit_group_service_payment(uuid, numeric, text)
  FROM PUBLIC;
GRANT EXECUTE ON FUNCTION public.submit_group_service_payment(uuid, numeric, text)
  TO authenticated;

CREATE OR REPLACE FUNCTION public.review_service_payment_receipt(
  target_payment_id uuid,
  approve_payment boolean,
  target_review_note text DEFAULT NULL
)
RETURNS void
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  payment public.participant_payments%ROWTYPE;
  participant public.service_participant_financials%ROWTYPE;
  request public.service_requests%ROWTYPE;
  updated_paid numeric;
  updated_balance numeric;
  group_complete boolean;
BEGIN
  IF auth.uid() IS NULL OR NOT public.can_manage_service_billing() THEN
    RAISE EXCEPTION 'Only an administrator can review payment receipts.';
  END IF;

  SELECT * INTO payment
    FROM public.participant_payments
    WHERE payment_id = target_payment_id
    FOR UPDATE;
  IF NOT FOUND OR payment.verification_status <> 'pending' THEN
    RAISE EXCEPTION 'This payment receipt is no longer awaiting review.';
  END IF;

  SELECT * INTO request
    FROM public.service_requests
    WHERE service_request_id = payment.service_request_id
    FOR UPDATE;
  IF NOT FOUND THEN
    RAISE EXCEPTION 'The service bill for this payment could not be found.';
  END IF;

  IF NOT approve_payment THEN
    UPDATE public.participant_payments
      SET verification_status = 'rejected',
          reviewed_by = auth.uid(),
          reviewed_at = now(),
          review_note = NULLIF(btrim(target_review_note), '')
      WHERE payment_id = target_payment_id;
    RETURN;
  END IF;

  IF payment.receipt_url IS NULL OR btrim(payment.receipt_url) = '' THEN
    RAISE EXCEPTION 'A payment receipt is required before approval.';
  END IF;

  SELECT * INTO participant
    FROM public.service_participant_financials
    WHERE service_request_id = payment.service_request_id
      AND user_id = payment.user_id
    FOR UPDATE;

  IF FOUND THEN
    updated_paid := participant.amount_paid + payment.amount;
    IF updated_paid > participant.total_due THEN
      RAISE EXCEPTION 'This payment is greater than the participant remaining balance.';
    END IF;

    UPDATE public.service_participant_financials
      SET amount_paid = updated_paid,
          status = CASE
            WHEN updated_paid >= participant.total_due THEN 'paid'
            WHEN updated_paid > 0 THEN 'partial'
            ELSE 'unpaid'
          END,
          last_payment_at = payment.payment_date
      WHERE participant_financial_id = participant.participant_financial_id;

    group_complete :=
      COALESCE(cardinality(request.participating_miners), 0) > 0
      AND (
        SELECT count(*)
          FROM public.service_participant_financials AS financial
          WHERE financial.service_request_id = payment.service_request_id
      ) = cardinality(request.participating_miners)
      AND NOT EXISTS (
        SELECT 1
          FROM public.service_participant_financials AS financial
          WHERE financial.service_request_id = payment.service_request_id
            AND financial.amount_paid < financial.total_due
      );

    UPDATE public.service_requests
      SET payment_amount = (
            SELECT COALESCE(SUM(financial.amount_paid), 0)
              FROM public.service_participant_financials AS financial
              WHERE financial.service_request_id = payment.service_request_id
          ),
          remaining_balance = (
            SELECT COALESCE(SUM(financial.total_due - financial.amount_paid), 0)
              FROM public.service_participant_financials AS financial
              WHERE financial.service_request_id = payment.service_request_id
          ),
          status = CASE
            WHEN group_complete THEN 'completed'
            WHEN EXISTS (
              SELECT 1
                FROM public.service_participant_financials AS financial
                WHERE financial.service_request_id = payment.service_request_id
                  AND financial.amount_paid > 0
            ) THEN 'partiallyPaid'
            ELSE status
          END,
          payment_date = CASE
            WHEN group_complete THEN now()
            ELSE payment_date
          END,
          billing_id = CASE
            WHEN group_complete THEN COALESCE(billing_id, 'BILL-' || floor(extract(epoch FROM now()) * 1000)::bigint::text)
            ELSE billing_id
          END,
          updated_at = now()
      WHERE service_request_id = payment.service_request_id;
  ELSE
    IF request.user_id <> payment.user_id THEN
      RAISE EXCEPTION 'The payment does not match a bill participant.';
    END IF;

    updated_paid := COALESCE(request.payment_amount, 0) + payment.amount;
    updated_balance := greatest(0, COALESCE(request.total_bill, 0) - updated_paid);
    IF updated_paid > COALESCE(request.total_bill, 0) THEN
      RAISE EXCEPTION 'This payment is greater than the remaining bill balance.';
    END IF;

    UPDATE public.service_requests
      SET payment_amount = updated_paid,
          remaining_balance = updated_balance,
          payment_receipt_url = payment.receipt_url,
          payment_date = payment.payment_date,
          status = CASE WHEN updated_balance = 0 THEN 'completed' ELSE 'partiallyPaid' END,
          billing_id = CASE
            WHEN updated_balance = 0 THEN COALESCE(billing_id, 'BILL-' || floor(extract(epoch FROM now()) * 1000)::bigint::text)
            ELSE billing_id
          END,
          updated_at = now()
      WHERE service_request_id = payment.service_request_id;
  END IF;

  UPDATE public.participant_payments
    SET verification_status = 'approved',
        reviewed_by = auth.uid(),
        reviewed_at = now(),
        review_note = NULLIF(btrim(target_review_note), '')
    WHERE payment_id = target_payment_id;
END;
$$;

REVOKE ALL ON FUNCTION public.review_service_payment_receipt(uuid, boolean, text)
  FROM PUBLIC;
GRANT EXECUTE ON FUNCTION public.review_service_payment_receipt(uuid, boolean, text)
  TO authenticated;
