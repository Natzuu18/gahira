-- Before running this file:
-- 1. Enable the pg_net and Vault extensions if they are not already enabled.
-- 2. In Supabase Vault, create a secret named
--    service_progress_push_webhook_secret with the same value as the
--    PUSH_WEBHOOK_SECRET Edge Function secret.
-- 3. Replace YOUR_PROJECT_REF below with the Supabase project ref.

create or replace function private.send_service_progress_push_webhook()
returns trigger
language plpgsql
security definer
set search_path = ''
as $function$
declare
  webhook_secret text;
begin
  select secret.decrypted_secret
    into webhook_secret
    from vault.decrypted_secrets as secret
   where secret.name = 'service_progress_push_webhook_secret';

  if nullif(btrim(webhook_secret), '') is null then
    raise warning 'Vault secret service_progress_push_webhook_secret is missing; skipping push delivery';
    return new;
  end if;

  begin
    perform net.http_post(
      url := 'https://YOUR_PROJECT_REF.supabase.co/functions/v1/service-progress-push',
      body := jsonb_build_object(
        'type', 'INSERT',
        'table', tg_table_name,
        'schema', tg_table_schema,
        'record', to_jsonb(new),
        'old_record', null
      ),
      headers := jsonb_build_object(
        'Content-Type', 'application/json',
        'x-push-webhook-secret', webhook_secret
      )
    );
  exception when others then
    raise warning 'Could not enqueue service progress push (SQLSTATE %); continuing without push', SQLSTATE;
  end;

  return new;
end;
$function$;

revoke all on function private.send_service_progress_push_webhook()
  from public, anon, authenticated;

drop trigger if exists service_progress_push_webhook
  on public.service_progress_notifications;

create trigger service_progress_push_webhook
  after insert on public.service_progress_notifications
  for each row
  execute function private.send_service_progress_push_webhook();
