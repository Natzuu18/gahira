-- Run this migration in the Supabase SQL editor or with the project's
-- migration workflow before enabling the service-progress webhook.

create table if not exists public.push_device_tokens (
  fid text primary key,
  user_id uuid not null references public.users ("userId") on delete cascade,
  platform text not null check (platform in ('android', 'ios')),
  updated_at timestamptz not null default now()
);

alter table public.push_device_tokens enable row level security;
grant select, insert, update, delete on public.push_device_tokens to authenticated;

drop policy if exists "Users manage their own push tokens"
  on public.push_device_tokens;
create policy "Users manage their own push tokens"
  on public.push_device_tokens
  for all
  to authenticated
  using ((select auth.uid()) = user_id)
  with check ((select auth.uid()) = user_id);

create table if not exists public.service_progress_notifications (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null references public.users ("userId") on delete cascade,
  service_request_id uuid not null references public.service_requests (service_request_id) on delete cascade,
  title text not null,
  body text not null,
  data jsonb not null default '{}'::jsonb,
  created_at timestamptz not null default now()
);

create index if not exists service_progress_notifications_user_created_idx
  on public.service_progress_notifications (user_id, created_at desc);

alter table public.service_progress_notifications enable row level security;
grant select on public.service_progress_notifications to authenticated;
drop policy if exists "Miners read their own service progress notifications"
  on public.service_progress_notifications;
create policy "Miners read their own service progress notifications"
  on public.service_progress_notifications
  for select
  to authenticated
  using ((select auth.uid()) = user_id);

create schema if not exists private;
revoke all on schema private from public, anon, authenticated;

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
      select unnest(coalesce(sr.participating_miners, '{}'::uuid[])) as recipient_id
        from public.service_requests sr
       where sr.service_request_id = p_service_request_id
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
  if auth.uid() is null then
    return new;
  end if;

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

  update_label := coalesce(stage_label, replace(new.status, '_', ' '), 'service');
  perform private.create_service_progress_notifications(
    new.service_request_id,
    'Service progress update',
    'Your service has an update: ' || update_label || '.'
  );
  return new;
end;
$$;

create or replace function private.notify_milling_batch_progress()
returns trigger
language plpgsql
security definer
set search_path = pg_catalog, public, private
as $$
declare
  update_label text;
begin
  if auth.uid() is null then
    return new;
  end if;

  if tg_op = 'INSERT' then
    if new.batch_kind <> 'milling' or new.milling_started_at is null then
      return new;
    end if;
    update_label := 'Milling has started for a batch.';
    perform private.create_service_progress_notifications(
      new.service_request_id,
      'Service progress update',
      update_label
    );
    return new;
  end if;

  if tg_op = 'UPDATE'
     and old.status is not distinct from new.status
     and old.milling_started_at is not distinct from new.milling_started_at
     and old.completed_at is not distinct from new.completed_at
     and old.unloading_started_at is not distinct from new.unloading_started_at
     and old.unloading_completed_at is not distinct from new.unloading_completed_at
     and old.washing_started_at is not distinct from new.washing_started_at
     and old.washing_completed_at is not distinct from new.washing_completed_at then
    return new;
  end if;

  update_label := case
    when old.washing_started_at is distinct from new.washing_started_at then 'Washing has started for a batch.'
    when old.washing_completed_at is distinct from new.washing_completed_at then 'Washing is complete for a batch.'
    when old.unloading_started_at is distinct from new.unloading_started_at then 'Unloading has started for a batch.'
    when old.unloading_completed_at is distinct from new.unloading_completed_at then 'A batch has been unloaded.'
    when old.milling_started_at is distinct from new.milling_started_at then 'Milling has started for a batch.'
    when old.completed_at is distinct from new.completed_at then 'A milling batch is complete.'
    else 'A processing batch status changed to ' || replace(new.status, '_', ' ') || '.'
  end;

  perform private.create_service_progress_notifications(
    new.service_request_id,
    'Service progress update',
    update_label
  );
  return new;
end;
$$;

create or replace function private.notify_ongoing_service_progress()
returns trigger
language plpgsql
security definer
set search_path = pg_catalog, public, private
as $$
begin
  if auth.uid() is null then
    return new;
  end if;

  perform private.create_service_progress_notifications(
    new.service_request_id,
    'Service progress update',
    'An operator has claimed your service.'
  );
  return new;
end;
$$;

revoke all on function private.create_service_progress_notifications(uuid, text, text)
  from public, anon, authenticated;
revoke all on function private.notify_service_request_progress()
  from public, anon, authenticated;
revoke all on function private.notify_milling_batch_progress()
  from public, anon, authenticated;
revoke all on function private.notify_ongoing_service_progress()
  from public, anon, authenticated;

drop trigger if exists service_request_progress_push on public.service_requests;
create trigger service_request_progress_push
  after update on public.service_requests
  for each row execute function private.notify_service_request_progress();

drop trigger if exists milling_batch_progress_push on public.milling_batches;
create trigger milling_batch_progress_push
  after insert or update on public.milling_batches
  for each row execute function private.notify_milling_batch_progress();

drop trigger if exists ongoing_service_progress_push on public.ongoing_services;
create trigger ongoing_service_progress_push
  after insert on public.ongoing_services
  for each row execute function private.notify_ongoing_service_progress();
