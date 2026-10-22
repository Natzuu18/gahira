-- Allow service_requests to enter the emergency stop state used by the app.
ALTER TABLE public.service_requests
  DROP CONSTRAINT IF EXISTS service_requests_status_check;

ALTER TABLE public.service_requests
  ADD CONSTRAINT service_requests_status_check
  CHECK (status IN (
    'draft',
    'pending',
    'pendingOperatorVerification',
    'returnedToMiner',
    'accepted',
    'verified',
    'queued',
    'scheduled',
    'assigned',
    'processing',
    'processingCompleted',
    'goldHandoff',
    'partiallyPaid',
    'completed',
    'cancelled',
    'emergencyStop'
  ));
