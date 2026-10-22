-- Keep any previously completed "reviewed" appeals as resolved before adding
-- the new decision states.
ALTER TABLE public.operator_verification_appeals
  DROP CONSTRAINT IF EXISTS operator_verification_appeals_status_check;

ALTER TABLE public.operator_verification_appeals
  ADD COLUMN IF NOT EXISTS admin_response text;
ALTER TABLE public.operator_verification_appeals
  ADD COLUMN IF NOT EXISTS miner_decision text
  CHECK (miner_decision IN ('continue', 'cancel'));

DROP INDEX IF EXISTS public.operator_verification_appeals_one_pending_idx;
CREATE UNIQUE INDEX IF NOT EXISTS operator_verification_appeals_one_unresolved_idx
  ON public.operator_verification_appeals (service_request_id, miner_id)
  WHERE status = 'pending'
     OR (status = 'rejected' AND miner_decision IS NULL);

UPDATE public.operator_verification_appeals
SET status = 'resolved'
WHERE status = 'reviewed';

ALTER TABLE public.operator_verification_appeals
  ADD CONSTRAINT operator_verification_appeals_status_check
  CHECK (status IN ('pending', 'resolved', 'rejected'));

-- Permit the admin review screen to read and correct verified material rows
-- when row-level security is enabled on this existing table.
DROP POLICY IF EXISTS "Admins can read verified material for appeal review"
  ON public.operator_verified_services;
CREATE POLICY "Admins can read verified material for appeal review"
  ON public.operator_verified_services
  FOR SELECT TO authenticated
  USING (
    EXISTS (
      SELECT 1
      FROM public.users u
      JOIN public.role r ON r.role_id = u.role_id
      WHERE u."userId" = (SELECT auth.uid())
        AND lower(r.role) = 'admin'
    )
  );

DROP POLICY IF EXISTS "Admins can update verified material after appeal"
  ON public.operator_verified_services;
CREATE POLICY "Admins can update verified material after appeal"
  ON public.operator_verified_services
  FOR UPDATE TO authenticated
  USING (
    EXISTS (
      SELECT 1
      FROM public.users u
      JOIN public.role r ON r.role_id = u.role_id
      WHERE u."userId" = (SELECT auth.uid())
        AND lower(r.role) = 'admin'
    )
  )
  WITH CHECK (
    EXISTS (
      SELECT 1
      FROM public.users u
      JOIN public.role r ON r.role_id = u.role_id
      WHERE u."userId" = (SELECT auth.uid())
        AND lower(r.role) = 'admin'
    )
  );

DROP POLICY IF EXISTS "Miners can choose after appeal rejection"
  ON public.operator_verification_appeals;
CREATE POLICY "Miners can choose after appeal rejection"
  ON public.operator_verification_appeals
  FOR UPDATE TO authenticated
  USING (
    miner_id = (SELECT auth.uid())
    AND status = 'rejected'
    AND miner_decision IS NULL
  )
  WITH CHECK (
    miner_id = (SELECT auth.uid())
    AND status = 'rejected'
    AND miner_decision IN ('continue', 'cancel')
  );

-- Keep the initial and revised appeal migrations safe to apply more than once.
DROP POLICY IF EXISTS "Miners can submit appeals for their verified requests"
  ON public.operator_verification_appeals;
CREATE POLICY "Miners can submit appeals for their verified requests"
  ON public.operator_verification_appeals
  FOR INSERT TO authenticated
  WITH CHECK (
    miner_id = (SELECT auth.uid())
    AND status = 'pending'
    AND miner_decision IS NULL
    AND reviewed_by IS NULL
    AND reviewed_at IS NULL
    AND EXISTS (
      SELECT 1
      FROM public.service_requests sr
      WHERE sr.service_request_id = operator_verification_appeals.service_request_id
        AND (
          sr.user_id = (SELECT auth.uid())
          OR (SELECT auth.uid()) = ANY(sr.participating_miners)
        )
        AND sr.status IN (
          'verified', 'accepted', 'queued', 'scheduled', 'assigned'
        )
        AND EXISTS (
          SELECT 1
          FROM public.operator_verified_services ovs
          WHERE ovs.service_request_id = sr.service_request_id
        )
    )
  );

DROP POLICY IF EXISTS "Assigned operators can view service appeal holds"
  ON public.operator_verification_appeals;
CREATE POLICY "Assigned operators can view service appeal holds"
  ON public.operator_verification_appeals
  FOR SELECT TO authenticated
  USING (
    EXISTS (
      SELECT 1
      FROM public.ongoing_services os
      WHERE os.service_request_id =
            operator_verification_appeals.service_request_id
        AND os.operator_id = (SELECT auth.uid())
    )
  );

-- Stop services from being claimed or started while any appeal is pending,
-- or after rejection until the miner chooses continue or cancel.
CREATE SCHEMA IF NOT EXISTS private;
REVOKE ALL ON SCHEMA private FROM PUBLIC, anon, authenticated;

CREATE OR REPLACE FUNCTION private.guard_service_status_during_appeal()
RETURNS trigger
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = ''
AS $$
BEGIN
  IF NEW.status NOT IN (
    'processing', 'processingCompleted', 'goldHandoff', 'partiallyPaid', 'completed'
  ) THEN
    RETURN NEW;
  END IF;

  IF EXISTS (
    SELECT 1
    FROM public.operator_verification_appeals a
    WHERE a.service_request_id = NEW.service_request_id
      AND (
        a.status = 'pending'
        OR (a.status = 'rejected' AND a.miner_decision IS NULL)
      )
  ) THEN
    RAISE EXCEPTION 'This service is on hold until the appeal is resolved and the miner decides whether to continue.'
      USING ERRCODE = 'P0001';
  END IF;

  RETURN NEW;
END;
$$;

CREATE OR REPLACE FUNCTION private.guard_ongoing_service_during_appeal()
RETURNS trigger
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = ''
AS $$
BEGIN
  IF EXISTS (
    SELECT 1
    FROM public.operator_verification_appeals a
    WHERE a.service_request_id = NEW.service_request_id
      AND (
        a.status = 'pending'
        OR (a.status = 'rejected' AND a.miner_decision IS NULL)
      )
  ) THEN
    RAISE EXCEPTION 'This service is on hold until the appeal is resolved and the miner decides whether to continue.'
      USING ERRCODE = 'P0001';
  END IF;

  RETURN NEW;
END;
$$;

REVOKE ALL ON FUNCTION private.guard_service_status_during_appeal() FROM PUBLIC, anon, authenticated;
REVOKE ALL ON FUNCTION private.guard_ongoing_service_during_appeal() FROM PUBLIC, anon, authenticated;

DROP TRIGGER IF EXISTS guard_service_status_during_appeal
  ON public.service_requests;
CREATE TRIGGER guard_service_status_during_appeal
  BEFORE UPDATE OF status ON public.service_requests
  FOR EACH ROW
  EXECUTE FUNCTION private.guard_service_status_during_appeal();

DROP TRIGGER IF EXISTS guard_ongoing_service_during_appeal
  ON public.ongoing_services;
CREATE TRIGGER guard_ongoing_service_during_appeal
  BEFORE INSERT OR UPDATE ON public.ongoing_services
  FOR EACH ROW
  EXECUTE FUNCTION private.guard_ongoing_service_during_appeal();
