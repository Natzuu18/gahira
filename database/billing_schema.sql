CREATE EXTENSION IF NOT EXISTS pgcrypto;

ALTER TABLE public.service_requests
  ADD COLUMN IF NOT EXISTS billing_id text,
  ADD COLUMN IF NOT EXISTS gold_weight_grams numeric(10,2),
  ADD COLUMN IF NOT EXISTS gold_buying_price numeric(10,2),
  ADD COLUMN IF NOT EXISTS gold_purchase_value numeric(10,2),
  ADD COLUMN IF NOT EXISTS deduct_bill_from_gold boolean DEFAULT false,
  ADD COLUMN IF NOT EXISTS processing_fee numeric(10,2) DEFAULT 0,
  ADD COLUMN IF NOT EXISTS other_expenses numeric(10,2) DEFAULT 0,
  ADD COLUMN IF NOT EXISTS total_bill numeric(10,2) DEFAULT 0,
  ADD COLUMN IF NOT EXISTS amount_to_miner numeric(10,2) DEFAULT 0,
  ADD COLUMN IF NOT EXISTS payment_amount numeric(10,2) DEFAULT 0,
  ADD COLUMN IF NOT EXISTS remaining_balance numeric(10,2) DEFAULT 0,
  ADD COLUMN IF NOT EXISTS payment_receipt_url text,
  ADD COLUMN IF NOT EXISTS payment_date timestamp with time zone;

-- Keep the database status values aligned with ServiceRequestStatus in the app.
ALTER TABLE public.service_requests
  DROP CONSTRAINT IF EXISTS service_requests_status_check;

ALTER TABLE public.service_requests
  ADD CONSTRAINT service_requests_status_check CHECK (
    status IN (
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
      'cancelled'
    )
  ) NOT VALID;

CREATE TABLE IF NOT EXISTS public.service_participant_financials (
  participant_financial_id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  service_request_id uuid NOT NULL REFERENCES public.service_requests(service_request_id) ON DELETE CASCADE,
  user_id uuid NOT NULL REFERENCES public.users("userId"),
  share_amount numeric(10,2) NOT NULL DEFAULT 0,
  individual_expenses numeric(10,2) NOT NULL DEFAULT 0,
  individual_expense_reason text,
  total_due numeric(10,2) NOT NULL DEFAULT 0,
  amount_paid numeric(10,2) NOT NULL DEFAULT 0,
  status text NOT NULL DEFAULT 'unpaid',
  last_payment_at timestamp with time zone,
  UNIQUE (service_request_id, user_id)
);

ALTER TABLE public.service_participant_financials
  ADD COLUMN IF NOT EXISTS individual_expense_reason text;

CREATE TABLE IF NOT EXISTS public.participant_payments (
  payment_id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  participant_financial_id uuid REFERENCES public.service_participant_financials(participant_financial_id) ON DELETE CASCADE,
  service_request_id uuid NOT NULL REFERENCES public.service_requests(service_request_id) ON DELETE CASCADE,
  user_id uuid NOT NULL REFERENCES public.users("userId"),
  amount numeric(10,2) NOT NULL CHECK (amount > 0),
  receipt_url text,
  payment_date timestamp with time zone NOT NULL DEFAULT now(),
  recorded_by uuid REFERENCES public.users("userId")
);

CREATE TABLE IF NOT EXISTS public.service_billing_items (
  item_id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  service_request_id uuid NOT NULL REFERENCES public.service_requests(service_request_id) ON DELETE CASCADE,
  item_name text NOT NULL,
  amount numeric(10,2) NOT NULL CHECK (amount >= 0),
  category text NOT NULL DEFAULT 'other',
  created_at timestamp with time zone NOT NULL DEFAULT now()
);

CREATE TABLE IF NOT EXISTS public.refinery_overhead_expenses (
  expense_id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  description text NOT NULL,
  amount numeric(10,2) NOT NULL CHECK (amount >= 0),
  category text NOT NULL,
  expense_date date NOT NULL DEFAULT CURRENT_DATE,
  recorded_by uuid REFERENCES public.users("userId"),
  created_at timestamp with time zone NOT NULL DEFAULT now()
);

CREATE INDEX IF NOT EXISTS service_participant_financials_request_idx
  ON public.service_participant_financials(service_request_id);

CREATE INDEX IF NOT EXISTS participant_payments_request_idx
  ON public.participant_payments(service_request_id);

CREATE INDEX IF NOT EXISTS service_billing_items_request_idx
  ON public.service_billing_items(service_request_id);

CREATE INDEX IF NOT EXISTS refinery_overhead_expenses_date_idx
  ON public.refinery_overhead_expenses(expense_date);

CREATE TABLE IF NOT EXISTS public.sms_templates (
  template_id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  name text NOT NULL UNIQUE,
  category text NOT NULL DEFAULT 'General',
  message text NOT NULL,
  created_at timestamp with time zone NOT NULL DEFAULT now(),
  updated_at timestamp with time zone NOT NULL DEFAULT now()
);

CREATE TABLE IF NOT EXISTS public.sms_notifications (
  notification_id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  recipient text NOT NULL,
  recipient_name text,
  message text NOT NULL,
  type text NOT NULL DEFAULT 'Manual Message',
  status text NOT NULL CHECK (status IN ('Delivered', 'Failed')),
  provider_message text,
  sent_at timestamp with time zone NOT NULL DEFAULT now(),
  sent_by uuid REFERENCES public.users("userId")
);

CREATE INDEX IF NOT EXISTS sms_notifications_sent_at_idx
  ON public.sms_notifications(sent_at DESC);

INSERT INTO public.sms_templates (name, category, message) VALUES
  ('Processing Update', 'Processing', 'Your gold processing job {JOB_ID} has moved to {STAGE} stage.'),
  ('Payment Confirmation', 'Billing', 'Payment of {AMOUNT} for invoice {INVOICE_ID} has been received.'),
  ('Maintenance Reminder', 'Maintenance', 'Scheduled maintenance for {EQUIPMENT} on {DATE} at {TIME}.')
ON CONFLICT (name) DO NOTHING;