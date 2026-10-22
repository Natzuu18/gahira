-- Preserve the verifier's display name with each service verification.
-- Run once in the Supabase SQL Editor.

alter table public.operator_verified_services
  add column if not exists operator_name text;

update public.operator_verified_services verified
   set operator_name = concat_ws(
     ' ',
     nullif(btrim(u.fname), ''),
     nullif(btrim(u.lname), '')
   )
  from public.users u
 where u."userId" = verified.operator_id
   and nullif(btrim(verified.operator_name), '') is null;

create or replace function public.set_operator_verification_name()
returns trigger
language plpgsql
security definer
set search_path = pg_catalog, public
as $$
begin
  select concat_ws(
           ' ',
           nullif(btrim(u.fname), ''),
           nullif(btrim(u.lname), '')
         )
    into new.operator_name
    from public.users u
   where u."userId" = new.operator_id;

  return new;
end;
$$;

revoke all on function public.set_operator_verification_name()
  from public, anon, authenticated;

drop trigger if exists operator_verification_name_snapshot
  on public.operator_verified_services;
create trigger operator_verification_name_snapshot
  before insert or update on public.operator_verified_services
  for each row execute function public.set_operator_verification_name();

create or replace function public.log_operator_service_verification()
returns trigger
language plpgsql
security definer
set search_path = pg_catalog, public
as $$
declare
  current_status text;
begin
  select sr.status
    into current_status
    from public.service_requests sr
   where sr.service_request_id = new.service_request_id;

  insert into public.audit_trails (
    service_request_id,
    user_id,
    action,
    previous_status,
    new_status,
    remarks,
    created_at
  )
  values (
    new.service_request_id,
    new.operator_id,
    'OPERATOR_VERIFICATION',
    current_status,
    current_status,
    'Operator verification recorded.',
    new.verified_at
  );

  return new;
end;
$$;

revoke all on function public.log_operator_service_verification()
  from public, anon, authenticated;

drop trigger if exists operator_service_verification_audit
  on public.operator_verified_services;
create trigger operator_service_verification_audit
  after insert on public.operator_verified_services
  for each row execute function public.log_operator_service_verification();

-- Add the verification event to audit history for records already in the table.
insert into public.audit_trails (
  service_request_id,
  user_id,
  action,
  previous_status,
  new_status,
  remarks,
  created_at
)
select verified.service_request_id,
       verified.operator_id,
       'OPERATOR_VERIFICATION',
       sr.status,
       sr.status,
       'Operator verification recorded.',
       verified.verified_at
  from public.operator_verified_services verified
  join public.service_requests sr
    on sr.service_request_id = verified.service_request_id
 where not exists (
   select 1
     from public.audit_trails audit
    where audit.service_request_id = verified.service_request_id
      and audit.user_id = verified.operator_id
      and audit.action = 'OPERATOR_VERIFICATION'
      and audit.created_at = verified.verified_at
 );
