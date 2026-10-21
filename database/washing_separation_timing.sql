-- Persist the operator's washing and separation start and stop times.
ALTER TABLE public.service_requests
  ADD COLUMN IF NOT EXISTS washing_started_at timestamptz,
  ADD COLUMN IF NOT EXISTS washing_completed_at timestamptz;
