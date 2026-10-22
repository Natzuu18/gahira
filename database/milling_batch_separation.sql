-- Run this migration in the Supabase SQL Editor before deploying the app changes.
-- Track separation as its own timed stage after washing.
BEGIN;

ALTER TABLE public.service_requests
  ADD COLUMN IF NOT EXISTS separation_started_at timestamptz,
  ADD COLUMN IF NOT EXISTS separation_completed_at timestamptz;

-- Existing requests that already reached refining completed separation as part
-- of the former combined washing and separation stage.
UPDATE public.service_requests
SET separation_started_at = COALESCE(separation_started_at, washing_started_at),
    separation_completed_at = COALESCE(separation_completed_at, washing_completed_at)
WHERE current_processing_stage IN ('refining', 'completed')
  AND washing_completed_at IS NOT NULL;

COMMIT;
