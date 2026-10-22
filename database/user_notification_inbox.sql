-- Apply after billing_schema.sql and miner_service_push_notifications.sql.
-- Extends the persistent service-progress inbox to all account roles and adds
-- read state plus application/payment notices.

alter table public.service_progress_notifications
  alter column service_request_id drop not null,
  add column if not exists read_at timestamptz;

create index if not exists service_progress_notifications_unread_idx
  on public.service_progress_notifications (user_id, created_at desc)
  where read_at is null;

grant select on public.service_progress_notifications to authenticated;
grant update (read_at) on public.service_progress_notifications to authenticated;
drop policy if exists "Miners read their own service progress notifications"
  on public.service_progress_notifications;
drop policy if exists "Users read their own notifications"
  on public.service_progress_notifications;
drop policy if exists "Users update their own notifications"
  on public.service_progress_notifications;

create policy "Users read their own notifications"
  on public.service_progress_notifications
  for select
  to authenticated
  using ((select auth.uid()) = user_id);

create policy "Users update their own notifications"
  on public.service_progress_notifications
  for update
  to authenticated
  using ((select auth.uid()) = user_id)
  with check ((select auth.uid()) = user_id);

create or replace function private.create_service_progress_notifications(
  p_service_request_id uuid,
  p_title text,
  p_body text
)
returns void
language plpgsql
security definer
set search_path = pg_catalog, public, private
as $$
begin
  insert into public.service_progress_notifications (
    user_id,
    service_request_id,
    title,
    body,
    data
  )
  select distinct recipient_id,
         p_service_request_id,
         p_title,
         p_body,
         jsonb_build_object('service_request_id', p_service_request_id)
    from (
      select sr.user_id as recipient_id
        from public.service_requests sr
       where sr.service_request_id = p_service_request_id
      union
      select unnest(coalesce(sr.participating_miners, '{}'::uuid[]))
        from public.service_requests sr
       where sr.service_request_id = p_service_request_id
      union
      select sr.assisted_by_operator_id
        from public.service_requests sr
       where sr.service_request_id = p_service_request_id
      union
      select os.operator_id
        from public.ongoing_services os
       where os.service_request_id = p_service_request_id
      union
      select mb.operator_id
        from public.milling_batches mb
       where mb.service_request_id = p_service_request_id
      union
      select u."userId"
        from public.users u
        join public.role r on r.role_id = u.role_id
       where lower(r.role) = 'admin'
    ) recipients
   where recipient_id is not null;
end;
$$;

create or replace function private.notify_service_request_progress()
returns trigger
language plpgsql
security definer
set search_path = pg_catalog, public, private
as $$
declare
  stage_label text;
  update_label text;
begin
  if old.status is not distinct from new.status
     and old.current_processing_stage is not distinct from new.current_processing_stage
     and old.emergency_stopped_at is not distinct from new.emergency_stopped_at
     and old.emergency_resolved_at is not distinct from new.emergency_resolved_at
     and old.separation_started_at is not distinct from new.separation_started_at
     and old.separation_completed_at is not distinct from new.separation_completed_at
     and old.refining_started_at is not distinct from new.refining_started_at
     and old.refining_completed_at is not distinct from new.refining_completed_at then
    return new;
  end if;

  stage_label := case new.current_processing_stage
    when 'rebagging' then 'sacking'
    when 'loading' then 'loading'
    when 'millingCrushing' then 'milling'
    when 'unloading' then 'unloading'
    when 'washingSeparation' then 'washing'
    when 'separation' then 'separation'
    when 'refining' then 'refining'
    when 'completed' then 'processing complete'
    else nullif(new.current_processing_stage, '')
  end;

  update_label := case
    when old.status is distinct from new.status
      then replace(new.status, '_', ' ')
    else coalesce(stage_label, replace(new.status, '_', ' '), 'service')
  end;
  perform private.create_service_progress_notifications(
    new.service_request_id,
    'Service progress update',
    'Your service has an update: ' || update_label || '.'
  );
  return new;
end;
$$;

create or replace function private.notify_application_update()
returns trigger
language plpgsql
security definer
set search_path = pg_catalog, public, private
as $$
declare
  notice_title text;
  notice_body text;
begin
  if old.status is distinct from new.status then
    notice_title := 'Application update';
    notice_body := 'Your application status is now ' || replace(new.status, '_', ' ') || '.';
  elsif old.appointment_date is distinct from new.appointment_date
     or old.appointment_time is distinct from new.appointment_time
     or old.appointment_status is distinct from new.appointment_status then
    notice_title := 'Interview schedule update';
    notice_body := coalesce(nullif(new.appointment_remarks, ''), 'Your interview schedule has been updated.');
  else
    return new;
  end if;

  insert into public.service_progress_notifications (user_id, title, body, data)
  values (
    new.user_id,
    notice_title,
    notice_body,
    jsonb_build_object('application_id', new.application_id)
  );
  return new;
end;
$$;

create or replace function private.notify_new_application()
returns trigger
language plpgsql
security definer
set search_path = pg_catalog, public, private
as $$
begin
  insert into public.service_progress_notifications (user_id, title, body, data)
  select u."userId",
         'New registration application',
         'A new registration application is awaiting review.',
         jsonb_build_object('application_id', new.application_id)
    from public.users u
    join public.role r on r.role_id = u.role_id
   where lower(r.role) = 'admin';
  return new;
end;
$$;

create or replace function private.notify_new_service_request()
returns trigger
language plpgsql
security definer
set search_path = pg_catalog, public, private
as $$
begin
  perform private.create_service_progress_notifications(
    new.service_request_id,
    'Service request received',
    'A service request is awaiting verification.'
  );
  return new;
end;
$$;

create or replace function private.notify_participant_payment()
returns trigger
language plpgsql
security definer
set search_path = pg_catalog, public, private
as $$
declare
  notice_body text;
begin
  if tg_op = 'UPDATE' then
    if old.amount is not distinct from new.amount
       and old.verification_status is not distinct from new.verification_status then
      return new;
    end if;
  end if;

  if tg_op = 'INSERT' then
    notice_body := case
      when lower(new.verification_status) = 'approved'
        then 'A payment was recorded for your service.'
      else 'A payment was submitted for your service and is awaiting review.'
    end;
  else
    notice_body := 'Your payment status is now ' || replace(new.verification_status, '_', ' ') || '.';
  end if;

  perform private.create_service_progress_notifications(
    new.service_request_id,
    'Payment update',
    notice_body
  );
  return new;
end;
$$;

revoke all on function private.notify_application_update()
  from public, anon, authenticated;
revoke all on function private.notify_new_application()
  from public, anon, authenticated;
revoke all on function private.notify_new_service_request()
  from public, anon, authenticated;
revoke all on function private.notify_participant_payment()
  from public, anon, authenticated;

drop trigger if exists application_notification_update on public.applications;
create trigger application_notification_update
  after update on public.applications
  for each row execute function private.notify_application_update();

drop trigger if exists application_notification_insert on public.applications;
create trigger application_notification_insert
  after insert on public.applications
  for each row execute function private.notify_new_application();

drop trigger if exists service_request_notification_insert on public.service_requests;
create trigger service_request_notification_insert
  after insert on public.service_requests
  for each row execute function private.notify_new_service_request();

drop trigger if exists participant_payment_notification on public.participant_payments;
create trigger participant_payment_notification
  after insert or update on public.participant_payments
  for each row execute function private.notify_participant_payment();
