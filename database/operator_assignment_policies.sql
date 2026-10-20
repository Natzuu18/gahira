-- Allow admins to assign active operators to services while keeping
-- ongoing_services protected by row-level security.

CREATE OR REPLACE FUNCTION public.can_administer_service_assignments()
RETURNS boolean
LANGUAGE sql
STABLE
SECURITY DEFINER
SET search_path = public
AS $$
  SELECT EXISTS (
    SELECT 1
    FROM public.users AS account
    JOIN public.role AS account_role ON account_role.role_id = account.role_id
    WHERE account."userId" = auth.uid()
      AND lower(account_role.role) = 'admin'
      AND lower(account.status) IN ('active', 'approved')
  );
$$;

CREATE OR REPLACE FUNCTION public.is_active_operator_account(operator_user_id uuid)
RETURNS boolean
LANGUAGE sql
STABLE
SECURITY DEFINER
SET search_path = public
AS $$
  SELECT EXISTS (
    SELECT 1
    FROM public.users AS account
    JOIN public.role AS account_role ON account_role.role_id = account.role_id
    WHERE account."userId" = operator_user_id
      AND lower(account_role.role) = 'operator'
      AND lower(account.status) IN ('active', 'approved')
  );
$$;

REVOKE ALL ON FUNCTION public.can_administer_service_assignments() FROM PUBLIC;
REVOKE ALL ON FUNCTION public.is_active_operator_account(uuid) FROM PUBLIC;
GRANT EXECUTE ON FUNCTION public.can_administer_service_assignments() TO authenticated;
GRANT EXECUTE ON FUNCTION public.is_active_operator_account(uuid) TO authenticated;

ALTER TABLE public.ongoing_services ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS ongoing_services_admin_or_operator_read
  ON public.ongoing_services;
CREATE POLICY ongoing_services_admin_or_operator_read
  ON public.ongoing_services
  FOR SELECT
  TO authenticated
  USING (
    public.can_administer_service_assignments()
    OR (
      operator_id = auth.uid()
      AND public.is_active_operator_account(auth.uid())
    )
  );

DROP POLICY IF EXISTS ongoing_services_admin_insert_assignment
  ON public.ongoing_services;
CREATE POLICY ongoing_services_admin_insert_assignment
  ON public.ongoing_services
  FOR INSERT
  TO authenticated
  WITH CHECK (
    public.can_administer_service_assignments()
    AND public.is_active_operator_account(operator_id)
    AND EXISTS (
      SELECT 1
      FROM public.service_requests AS request
      WHERE request.service_request_id = ongoing_services.service_request_id
        AND request.status IN ('verified', 'accepted', 'queued', 'scheduled', 'assigned')
    )
  );

DROP POLICY IF EXISTS ongoing_services_admin_update_assignment
  ON public.ongoing_services;
CREATE POLICY ongoing_services_admin_update_assignment
  ON public.ongoing_services
  FOR UPDATE
  TO authenticated
  USING (public.can_administer_service_assignments())
  WITH CHECK (
    public.can_administer_service_assignments()
    AND public.is_active_operator_account(operator_id)
    AND EXISTS (
      SELECT 1
      FROM public.service_requests AS request
      WHERE request.service_request_id = ongoing_services.service_request_id
        AND request.status IN ('verified', 'accepted', 'queued', 'scheduled', 'assigned')
    )
  );

DROP POLICY IF EXISTS ongoing_services_operator_claim
  ON public.ongoing_services;
CREATE POLICY ongoing_services_operator_claim
  ON public.ongoing_services
  FOR INSERT
  TO authenticated
  WITH CHECK (
    operator_id = auth.uid()
    AND public.is_active_operator_account(auth.uid())
    AND EXISTS (
      SELECT 1
      FROM public.service_requests AS request
      WHERE request.service_request_id = ongoing_services.service_request_id
        AND request.status IN ('verified', 'accepted', 'queued', 'scheduled')
    )
  );

DROP POLICY IF EXISTS ongoing_services_operator_update_own_assignment
  ON public.ongoing_services;
CREATE POLICY ongoing_services_operator_update_own_assignment
  ON public.ongoing_services
  FOR UPDATE
  TO authenticated
  USING (
    operator_id = auth.uid()
    AND public.is_active_operator_account(auth.uid())
  )
  WITH CHECK (
    operator_id = auth.uid()
    AND public.is_active_operator_account(auth.uid())
  );
