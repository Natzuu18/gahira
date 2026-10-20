CREATE TABLE IF NOT EXISTS public.profile_activity_logs (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  profile_user_id uuid NOT NULL REFERENCES public.users("userId") ON DELETE CASCADE,
  updated_by uuid REFERENCES public.users("userId") ON DELETE SET NULL,
  updated_by_name text NOT NULL,
  updated_by_role text NOT NULL DEFAULT '',
  changed_fields text[] NOT NULL,
  created_at timestamp with time zone NOT NULL DEFAULT now()
);

CREATE INDEX IF NOT EXISTS profile_activity_logs_user_created_idx
  ON public.profile_activity_logs(profile_user_id, created_at DESC);

ALTER TABLE public.profile_activity_logs ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS profile_activity_logs_read_own
  ON public.profile_activity_logs;
CREATE POLICY profile_activity_logs_read_own
  ON public.profile_activity_logs
  FOR SELECT
  TO authenticated
  USING (profile_user_id = auth.uid());

GRANT SELECT ON public.profile_activity_logs TO authenticated;

CREATE OR REPLACE FUNCTION public.log_user_profile_update()
RETURNS trigger
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  actor_id uuid := auth.uid();
  actor_name text := 'System';
  actor_role text := '';
  changed_fields text[];
BEGIN
  changed_fields := array_remove(ARRAY[
    CASE WHEN NEW.fname IS DISTINCT FROM OLD.fname THEN 'First name' END,
    CASE WHEN NEW.mname IS DISTINCT FROM OLD.mname THEN 'Middle name' END,
    CASE WHEN NEW.lname IS DISTINCT FROM OLD.lname THEN 'Last name' END,
    CASE WHEN NEW.contact_num IS DISTINCT FROM OLD.contact_num THEN 'Contact number' END,
    CASE WHEN NEW.address IS DISTINCT FROM OLD.address THEN 'Address' END
  ]::text[], NULL);

  IF cardinality(changed_fields) = 0 THEN
    RETURN NEW;
  END IF;

  IF actor_id IS NOT NULL THEN
    SELECT concat_ws(' ', u.fname, u.lname), COALESCE(r.role, '')
      INTO actor_name, actor_role
      FROM public.users AS u
      LEFT JOIN public.role AS r ON r.role_id = u.role_id
      WHERE u."userId" = actor_id;

    actor_name := COALESCE(NULLIF(actor_name, ''), 'Unknown user');
    actor_role := COALESCE(actor_role, '');
  END IF;

  INSERT INTO public.profile_activity_logs (
    profile_user_id,
    updated_by,
    updated_by_name,
    updated_by_role,
    changed_fields
  )
  VALUES (
    NEW."userId",
    actor_id,
    actor_name,
    actor_role,
    changed_fields
  );

  RETURN NEW;
END;
$$;

DROP TRIGGER IF EXISTS users_profile_activity_log
  ON public.users;
CREATE TRIGGER users_profile_activity_log
  AFTER UPDATE OF fname, mname, lname, address, contact_num
  ON public.users
  FOR EACH ROW
  EXECUTE FUNCTION public.log_user_profile_update();
