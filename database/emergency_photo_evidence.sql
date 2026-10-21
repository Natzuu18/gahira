-- Stores the public Storage URL for an optional emergency stop photo.
-- Emergency photos are uploaded to the existing serviceRequests bucket.
alter table public.service_requests
  add column if not exists emergency_evidence_url text;

notify pgrst, 'reload schema';
