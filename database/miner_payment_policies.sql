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
  updated_paid numeric;
BEGIN
  IF auth.uid() IS NULL THEN
    RAISE EXCEPTION 'You must be signed in to pay this bill.';
  END IF;
  IF payment_amount IS NULL OR payment_amount <= 0 THEN
    RAISE EXCEPTION 'Payment amount must be greater than zero.';
  END IF;
  IF NOT public.is_service_billing_participant(
    target_service_request_id,
    auth.uid()
  ) THEN
    RAISE EXCEPTION 'You are not a participant in this service.';
  END IF;

  SELECT *
    INTO participant
    FROM public.service_participant_financials AS financial
    WHERE financial.service_request_id = target_service_request_id
      AND financial.user_id = auth.uid()
    FOR UPDATE;

  IF NOT FOUND THEN
    RAISE EXCEPTION 'Your group bill is not available yet.';
  END IF;

  remaining := greatest(
    0,
    participant.total_due - participant.amount_paid
  );
  IF payment_amount > remaining THEN
    RAISE EXCEPTION 'Payment exceeds your remaining balance of %.', remaining;
  END IF;

  updated_paid := least(
    participant.total_due,
    participant.amount_paid + payment_amount
  );

  UPDATE public.service_participant_financials
    SET amount_paid = updated_paid,
        status = CASE
          WHEN updated_paid >= participant.total_due THEN 'paid'
          WHEN updated_paid > 0 THEN 'partial'
          ELSE 'unpaid'
        END,
        last_payment_at = now()
    WHERE participant_financial_id = participant.participant_financial_id;

  INSERT INTO public.participant_payments (
    participant_financial_id,
    service_request_id,
    user_id,
    amount,
    receipt_url,
    payment_date,
    recorded_by
  ) VALUES (
    participant.participant_financial_id,
    target_service_request_id,
    auth.uid(),
    payment_amount,
    target_receipt_url,
    now(),
    auth.uid()
  );
END;
$$;

REVOKE ALL ON FUNCTION public.submit_group_service_payment(uuid, numeric, text)
  FROM PUBLIC;
GRANT EXECUTE ON FUNCTION public.submit_group_service_payment(uuid, numeric, text)
  TO authenticated;
