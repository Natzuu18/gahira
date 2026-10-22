CREATE TABLE IF NOT EXISTS public.operator_verification_appeals (
  appeal_id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  service_request_id uuid NOT NULL REFERENCES public.service_requests(service_request_id) ON DELETE CASCADE,
  miner_id uuid NOT NULL REFERENCES public.users("userId"),
  category text NOT NULL CHECK (category IN (
    'Incorrect sack count',
    'Incorrect material condition',
    'Incorrect material state',
    'Incorrect source details',
    'Verification photo issue',
    'Other'
  )),
  reason text NOT NULL CHECK (length(trim(reason)) > 0),
  appeal_date date NOT NULL DEFAULT CURRENT_DATE,
  status text NOT NULL DEFAULT 'pending' CHECK (status IN ('pending', 'resolved', 'rejected')),
  miner_decision text CHECK (miner_decision IN ('continue', 'cancel')),
  reviewed_by uuid REFERENCES public.users("userId"),
  reviewed_at timestamptz,
  admin_response text,
  created_at timestamptz NOT NULL DEFAULT now()
);

CREATE INDEX IF NOT EXISTS operator_verification_appeals_request_created_idx
  ON public.operator_verification_appeals (service_request_id, created_at DESC);

CREATE INDEX IF NOT EXISTS operator_verification_appeals_pending_idx
  ON public.operator_verification_appeals (created_at DESC)
  WHERE status = 'pending';

CREATE UNIQUE INDEX IF NOT EXISTS operator_verification_appeals_one_pending_idx
  ON public.operator_verification_appeals (service_request_id, miner_id)
  WHERE status = 'pending'
     OR (status = 'rejected' AND miner_decision IS NULL);

ALTER TABLE public.operator_verification_appeals ENABLE ROW LEVEL SECURITY;

CREATE POLICY "Miners can submit appeals for their verified requests"
  ON public.operator_verification_appeals
  FOR INSERT
  TO authenticated
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

CREATE POLICY "Request miners and admins can view appeals"
  ON public.operator_verification_appeals
  FOR SELECT
  TO authenticated
  USING (
    miner_id = (SELECT auth.uid())
    OR EXISTS (
      SELECT 1
      FROM public.service_requests sr
      WHERE sr.service_request_id = operator_verification_appeals.service_request_id
        AND (
          sr.user_id = (SELECT auth.uid())
          OR (SELECT auth.uid()) = ANY(sr.participating_miners)
        )
    )
    OR EXISTS (
      SELECT 1
      FROM public.users u
      JOIN public.role r ON r.role_id = u.role_id
      WHERE u."userId" = (SELECT auth.uid())
        AND lower(r.role) IN ('admin', 'owner')
    )
  );

CREATE POLICY "Admins can process verification appeals"
  ON public.operator_verification_appeals
  FOR UPDATE
  TO authenticated
  USING (
    EXISTS (
      SELECT 1
      FROM public.users u
      JOIN public.role r ON r.role_id = u.role_id
      WHERE u."userId" = (SELECT auth.uid())
        AND lower(r.role) IN ('admin', 'owner')
    )
  )
  WITH CHECK (
    EXISTS (
      SELECT 1
      FROM public.users u
      JOIN public.role r ON r.role_id = u.role_id
      WHERE u."userId" = (SELECT auth.uid())
        AND lower(r.role) IN ('admin', 'owner')
    )
  );

GRANT SELECT, INSERT, UPDATE ON public.operator_verification_appeals TO authenticated;
