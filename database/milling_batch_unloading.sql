-- Run this migration in the Supabase SQL Editor before deploying the app changes.
-- Track unloading independently for each completed milling batch.
BEGIN;

ALTER TABLE public.milling_batches
  ADD COLUMN IF NOT EXISTS unloading_started_at timestamptz,
  ADD COLUMN IF NOT EXISTS unloading_completed_at timestamptz;

-- Preserve unloading already recorded on existing service requests.
UPDATE public.milling_batches AS batch
SET unloading_started_at = request.unloading_started_at,
    unloading_completed_at = request.unloading_completed_at
FROM public.service_requests AS request
WHERE batch.service_request_id = request.service_request_id
  AND batch.batch_kind = 'milling'
  AND batch.status = 'completed'
  AND request.unloading_started_at IS NOT NULL;

-- Let in-flight services use the new per-batch unloading controls.
UPDATE public.service_requests AS request
SET current_processing_stage = 'millingCrushing'
WHERE request.current_processing_stage = 'unloading'
  AND EXISTS (
    SELECT 1
    FROM public.milling_batches AS batch
    WHERE batch.service_request_id = request.service_request_id
      AND batch.batch_kind = 'milling'
      AND batch.status = 'completed'
  );

COMMIT;
