-- Run this migration in the Supabase SQL Editor before deploying the app changes.
-- Track washing independently for each unloaded milling batch.
BEGIN;

ALTER TABLE public.milling_batches
  ADD COLUMN IF NOT EXISTS washing_started_at timestamptz,
  ADD COLUMN IF NOT EXISTS washing_completed_at timestamptz;

-- Preserve washing already recorded on existing service requests for batches
-- that were unloaded before this per-batch workflow was introduced.
UPDATE public.milling_batches AS batch
SET washing_started_at = request.washing_started_at,
    washing_completed_at = request.washing_completed_at
FROM public.service_requests AS request
WHERE batch.service_request_id = request.service_request_id
  AND batch.batch_kind = 'milling'
  AND batch.status = 'completed'
  AND batch.unloading_completed_at IS NOT NULL
  AND request.washing_started_at IS NOT NULL;

COMMIT;
