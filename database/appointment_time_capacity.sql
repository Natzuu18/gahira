-- Run this once in the Supabase SQL editor before deploying the app changes.
-- Existing appointments have no stored time, so the new column stays NULL for
-- them. New bookings write the selected hourly slot start time.

ALTER TABLE public.applications
  ADD COLUMN IF NOT EXISTS appointment_time time without time zone;

CREATE UNIQUE INDEX IF NOT EXISTS applications_one_active_booking_per_time_idx
  ON public.applications (appointment_date, appointment_time)
  WHERE appointment_date IS NOT NULL
    AND appointment_time IS NOT NULL
    AND status <> 'rejected';
