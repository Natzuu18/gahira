-- Run this migration in the Supabase SQL Editor before deploying the app changes.
-- Track the refining timer and its completion time.
BEGIN;

ALTER TABLE public.service_requests
  ADD COLUMN IF NOT EXISTS refining_started_at timestamptz,
  ADD COLUMN IF NOT EXISTS refining_completed_at timestamptz;

COMMIT;
