-- Run this migration in Supabase SQL Editor before deploying the app changes.
-- Sacking batches are saved first with no machine or drum assigned. Operators
-- enter a milling quantity from the request's total available resacked sacks.

begin;

alter table public.milling_batches
  alter column machine_id drop not null,
  alter column drum_id drop not null;

alter table public.milling_batches
  add column if not exists milling_started_at timestamptz,
  add column if not exists sacking_batch_id uuid,
  add column if not exists batch_kind text not null default 'legacy';

-- Classify existing prepared batches. Existing milling/completed records stay
-- legacy so they are not counted as new available sacking stock.
update public.milling_batches
set batch_kind = 'sacking'
where status = 'ready_to_mill'
  and batch_kind = 'legacy';

alter table public.milling_batches
  drop constraint if exists milling_batches_batch_kind_check;

alter table public.milling_batches
  add constraint milling_batches_batch_kind_check
  check (batch_kind in ('sacking', 'milling', 'legacy'));

alter table public.milling_batches
  drop constraint if exists fk_mb_sacking_batch;

alter table public.milling_batches
  add constraint fk_mb_sacking_batch
  foreign key (sacking_batch_id)
  references public.milling_batches(batch_id);

create index if not exists milling_batches_sacking_batch_id_idx
  on public.milling_batches (sacking_batch_id)
  where sacking_batch_id is not null;

alter table public.milling_batches
  drop constraint if exists milling_batches_status_check;

alter table public.milling_batches
  add constraint milling_batches_status_check
  check (status in ('ready_to_mill', 'milling', 'completed'));

-- Preserve the original start time for active and completed batches.
update public.milling_batches
set milling_started_at = created_at
where status in ('milling', 'completed')
  and milling_started_at is null;

commit;
