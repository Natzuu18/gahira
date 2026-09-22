-- WARNING: This schema is for context only and is not meant to be run.
-- Table order and constraints may not be valid for execution.

CREATE TABLE public.role (
  role_id uuid NOT NULL DEFAULT gen_random_uuid(),
  role character varying NOT NULL,
  status character varying NOT NULL DEFAULT 'active'::character varying,
  CONSTRAINT role_pkey PRIMARY KEY (role_id)
);
CREATE TABLE public.users (
  userId uuid NOT NULL DEFAULT gen_random_uuid(),
  fname character varying NOT NULL,
  mname character varying,
  lname character varying NOT NULL,
  address text NOT NULL,
  email character varying NOT NULL UNIQUE,
  contact_num character varying NOT NULL,
  role_id uuid NOT NULL,
  status character varying NOT NULL DEFAULT 'pending'::character varying,
  created_at timestamp with time zone NOT NULL DEFAULT now(),
  mining_unit_id uuid,
  pin_hash text,
  CONSTRAINT users_pkey PRIMARY KEY (userId),
  CONSTRAINT users_role_id_fkey FOREIGN KEY (role_id) REFERENCES public.role(role_id),
  CONSTRAINT users_mining_unit_id_fkey FOREIGN KEY (mining_unit_id) REFERENCES public.mining_units(id)
);
CREATE TABLE public.personal_details (
  document_id uuid NOT NULL DEFAULT gen_random_uuid(),
  user_id uuid NOT NULL,
  document bytea NOT NULL,
  uploaded_at timestamp with time zone NOT NULL DEFAULT now(),
  CONSTRAINT personal_details_pkey PRIMARY KEY (document_id),
  CONSTRAINT personal_details_user_id_fkey FOREIGN KEY (user_id) REFERENCES public.users(userId)
);
CREATE TABLE public.applications (
  application_id uuid NOT NULL DEFAULT gen_random_uuid(),
  user_id uuid NOT NULL,
  created_at timestamp with time zone NOT NULL DEFAULT now(),
  response_at timestamp with time zone,
  status character varying NOT NULL DEFAULT 'pending'::character varying,
  appointment_date date,
  appointment_status character varying DEFAULT 'scheduled'::character varying,
  appointment_remarks text,
  availability_id uuid,
  temp_pass text,
  document_id text,
  CONSTRAINT applications_pkey PRIMARY KEY (application_id),
  CONSTRAINT applications_user_id_fkey FOREIGN KEY (user_id) REFERENCES public.users(userId),
  CONSTRAINT applications_availability_id_fkey FOREIGN KEY (availability_id) REFERENCES public.appointment_availability(availability_id)
);
CREATE TABLE public.phone_otp_verifications (
  id uuid NOT NULL DEFAULT gen_random_uuid(),
  phone text NOT NULL,
  otp_hash text NOT NULL,
  attempts integer NOT NULL DEFAULT 0,
  verified boolean NOT NULL DEFAULT false,
  verification_token text,
  otp_expires_at timestamp with time zone NOT NULL,
  token_expires_at timestamp with time zone,
  consumed boolean NOT NULL DEFAULT false,
  created_at timestamp with time zone NOT NULL DEFAULT now(),
  CONSTRAINT phone_otp_verifications_pkey PRIMARY KEY (id)
);
CREATE TABLE public.appointment_availability (
  availability_id uuid NOT NULL DEFAULT gen_random_uuid(),
  date date NOT NULL,
  start_time time without time zone NOT NULL,
  end_time time without time zone NOT NULL,
  address character varying NOT NULL,
  status character varying DEFAULT 'open'::character varying,
  created_at timestamp with time zone NOT NULL DEFAULT now(),
  updated_at timestamp with time zone NOT NULL DEFAULT now(),
  CONSTRAINT appointment_availability_pkey PRIMARY KEY (availability_id)
);
CREATE TABLE public.mining_units (
  id uuid NOT NULL DEFAULT gen_random_uuid(),
  name text NOT NULL,
  type text NOT NULL CHECK (type = ANY (ARRAY['Ball Mill'::text, 'Processing Plant'::text, 'Tunnel'::text])),
  location text,
  created_at timestamp with time zone DEFAULT now(),
  CONSTRAINT mining_units_pkey PRIMARY KEY (id)
);
CREATE TABLE public.machines (
  machine_id uuid NOT NULL DEFAULT gen_random_uuid(),
  machine_name character varying NOT NULL,
  machine_code character varying NOT NULL UNIQUE,
  machine_type character varying,
  description text,
  location character varying,
  status character varying NOT NULL DEFAULT 'available'::character varying CHECK (status::text = ANY (ARRAY['available'::character varying, 'in_use'::character varying, 'maintenance'::character varying, 'inactive'::character varying]::text[])),
  created_at timestamp with time zone NOT NULL DEFAULT now(),
  updated_at timestamp with time zone NOT NULL DEFAULT now(),
  CONSTRAINT machines_pkey PRIMARY KEY (machine_id)
);
CREATE TABLE public.drums (
  drum_id uuid NOT NULL DEFAULT gen_random_uuid(),
  machine_id uuid NOT NULL,
  drum_name character varying NOT NULL,
  drum_code character varying NOT NULL UNIQUE,
  capacity character varying,
  description text,
  status character varying NOT NULL DEFAULT 'available'::character varying CHECK (status::text = ANY (ARRAY['available'::character varying, 'in_use'::character varying, 'maintenance'::character varying, 'inactive'::character varying]::text[])),
  created_at timestamp with time zone NOT NULL DEFAULT now(),
  updated_at timestamp with time zone NOT NULL DEFAULT now(),
  CONSTRAINT drums_pkey PRIMARY KEY (drum_id),
  CONSTRAINT fk_drums_machine FOREIGN KEY (machine_id) REFERENCES public.machines(machine_id)
);
CREATE TABLE public.machine_availability (
  availability_id uuid NOT NULL DEFAULT gen_random_uuid(),
  machine_id uuid NOT NULL,
  date date NOT NULL,
  start_time time without time zone NOT NULL,
  end_time time without time zone NOT NULL,
  status character varying NOT NULL DEFAULT 'available'::character varying CHECK (status::text = ANY (ARRAY['available'::character varying, 'reserved'::character varying, 'maintenance'::character varying, 'unavailable'::character varying]::text[])),
  remarks text,
  created_at timestamp with time zone NOT NULL DEFAULT now(),
  updated_at timestamp with time zone NOT NULL DEFAULT now(),
  CONSTRAINT machine_availability_pkey PRIMARY KEY (availability_id),
  CONSTRAINT fk_machine_availability_machine FOREIGN KEY (machine_id) REFERENCES public.machines(machine_id)
);
CREATE TABLE public.drum_availability (
  availability_id uuid NOT NULL DEFAULT gen_random_uuid(),
  drum_id uuid NOT NULL,
  date date NOT NULL,
  start_time time without time zone NOT NULL,
  end_time time without time zone NOT NULL,
  status character varying NOT NULL DEFAULT 'available'::character varying CHECK (status::text = ANY (ARRAY['available'::character varying, 'reserved'::character varying, 'maintenance'::character varying, 'unavailable'::character varying]::text[])),
  remarks text,
  created_at timestamp with time zone NOT NULL DEFAULT now(),
  updated_at timestamp with time zone NOT NULL DEFAULT now(),
  CONSTRAINT drum_availability_pkey PRIMARY KEY (availability_id),
  CONSTRAINT fk_drum_availability_drum FOREIGN KEY (drum_id) REFERENCES public.drums(drum_id)
);
CREATE TABLE public.maintenance_schedule (
  maintenance_id uuid NOT NULL DEFAULT gen_random_uuid(),
  machine_id uuid,
  drum_id uuid,
  maintenance_type character varying NOT NULL,
  maintenance_date date NOT NULL,
  start_time time without time zone NOT NULL,
  end_time time without time zone NOT NULL,
  description text,
  remarks text,
  status character varying NOT NULL DEFAULT 'scheduled'::character varying CHECK (status::text = ANY (ARRAY['scheduled'::character varying, 'ongoing'::character varying, 'completed'::character varying, 'cancelled'::character varying]::text[])),
  performed_by uuid,
  created_at timestamp with time zone NOT NULL DEFAULT now(),
  updated_at timestamp with time zone NOT NULL DEFAULT now(),
  CONSTRAINT maintenance_schedule_pkey PRIMARY KEY (maintenance_id),
  CONSTRAINT fk_maintenance_machine FOREIGN KEY (machine_id) REFERENCES public.machines(machine_id),
  CONSTRAINT fk_maintenance_drum FOREIGN KEY (drum_id) REFERENCES public.drums(drum_id),
  CONSTRAINT fk_maintenance_performed_by FOREIGN KEY (performed_by) REFERENCES public.users(userId)
);
CREATE TABLE public.service_availability (
  service_availability_id uuid NOT NULL DEFAULT gen_random_uuid(),
  service_type character varying NOT NULL,
  date date NOT NULL,
  start_time time without time zone NOT NULL,
  end_time time without time zone NOT NULL,
  max_requests integer NOT NULL DEFAULT 1 CHECK (max_requests > 0),
  current_requests integer NOT NULL DEFAULT 0,
  status character varying NOT NULL DEFAULT 'available'::character varying CHECK (status::text = ANY (ARRAY['available'::character varying, 'full'::character varying, 'unavailable'::character varying]::text[])),
  remarks text,
  created_at timestamp with time zone NOT NULL DEFAULT now(),
  updated_at timestamp with time zone NOT NULL DEFAULT now(),
  CONSTRAINT service_availability_pkey PRIMARY KEY (service_availability_id)
);
CREATE TABLE public.service_requests (
  service_request_id uuid NOT NULL DEFAULT gen_random_uuid(),
  user_id uuid NOT NULL,
  service_availability_id uuid,
  service_type character varying NOT NULL,
  request_date date NOT NULL,
  start_time time without time zone,
  end_time time without time zone,
  quantity integer NOT NULL DEFAULT 1 CHECK (quantity > 0),
  status character varying NOT NULL DEFAULT 'pending'::character varying CHECK (status::text = ANY (ARRAY['draft'::text, 'pending'::text, 'pendingOperatorVerification'::text, 'returnedToMiner'::text, 'accepted'::text, 'verified'::text, 'queued'::text, 'scheduled'::text, 'assigned'::text, 'processing'::text, 'processingCompleted'::text, 'goldHandoff'::text, 'partiallyPaid'::text, 'completed'::text, 'cancelled'::text])),
  approved_by uuid,
  approved_at timestamp with time zone,
  created_at timestamp with time zone NOT NULL DEFAULT now(),
  updated_at timestamp with time zone NOT NULL DEFAULT now(),
  material_condition text,
  material_state text,
  material_source_type text,
  material_source text,
  material_notes text,
  photo_urls ARRAY DEFAULT '{}'::text[],
  participating_miners ARRAY DEFAULT '{}'::uuid[],
  is_operator_assisted boolean DEFAULT false,
  assisted_by_operator_id uuid,
  current_processing_stage text,
  processing_notes text,
  billing_id text,
  sacked_quantity integer,
  miner_sacks_processed integer DEFAULT 0,
  unloading_started_at timestamp with time zone,
  unloading_completed_at timestamp with time zone,

  -- Financial Handling Fields (Owner App)
  gold_weight_grams numeric(10,2),
  gold_buying_price numeric(10,2),
  gold_purchase_value numeric(10,2),
  deduct_bill_from_gold boolean DEFAULT false,
  processing_fee numeric(10,2) DEFAULT 0,
  other_expenses numeric(10,2) DEFAULT 0,
  total_bill numeric(10,2) DEFAULT 0,
  amount_to_miner numeric(10,2) DEFAULT 0,
  payment_amount numeric(10,2) DEFAULT 0,
  remaining_balance numeric(10,2) DEFAULT 0,
  payment_receipt_url text,
  payment_date timestamp with time zone,

  CONSTRAINT service_requests_pkey PRIMARY KEY (service_request_id),
  CONSTRAINT fk_service_request_user FOREIGN KEY (user_id) REFERENCES public.users(userId),
  CONSTRAINT fk_service_request_availability FOREIGN KEY (service_availability_id) REFERENCES public.service_availability(service_availability_id),
  CONSTRAINT fk_service_request_approved_by FOREIGN KEY (approved_by) REFERENCES public.users(userId),
  CONSTRAINT service_requests_assisted_by_operator_id_fkey FOREIGN KEY (assisted_by_operator_id) REFERENCES public.users(userId)
);

CREATE TABLE public.service_participant_financials (
    participant_financial_id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
    service_request_id uuid REFERENCES public.service_requests(service_request_id) ON DELETE CASCADE,
    user_id uuid REFERENCES public.users(userId),
    share_amount numeric(10,2) DEFAULT 0,
    individual_expenses numeric(10,2) DEFAULT 0,
    total_due numeric(10,2) DEFAULT 0,
    amount_paid numeric(10,2) DEFAULT 0,
    status text DEFAULT 'unpaid',
    last_payment_at timestamp with time zone,
    UNIQUE(service_request_id, user_id)
);

CREATE TABLE public.participant_payments (
    payment_id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
    participant_financial_id uuid REFERENCES public.service_participant_financials(participant_financial_id) ON DELETE CASCADE,
    amount numeric(10,2) NOT NULL,
    receipt_url text,
    payment_date timestamp with time zone DEFAULT now(),
    recorded_by uuid REFERENCES public.users(userId)
);

CREATE TABLE public.service_billing_items (
    item_id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
    service_request_id uuid REFERENCES public.service_requests(service_request_id) ON DELETE CASCADE,
    item_name text NOT NULL,
    amount numeric(10,2) NOT NULL,
    category text DEFAULT 'other', -- 'processing', 'maintenance', 'material', 'other'
    created_at timestamp with time zone DEFAULT now()
);

CREATE TABLE public.refinery_overhead_expenses (
    expense_id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
    description text NOT NULL,
    amount numeric(10,2) NOT NULL,
    category text NOT NULL, -- 'Utilities', 'Maintenance', 'Supplies', 'Salaries', etc.
    expense_date date NOT NULL DEFAULT CURRENT_DATE,
    recorded_by uuid REFERENCES public.users(userId),
    created_at timestamp with time zone DEFAULT now()
);
CREATE TABLE public.audit_trails (
  id uuid NOT NULL DEFAULT gen_random_uuid(),
  service_request_id uuid,
  user_id uuid,
  action text NOT NULL,
  previous_status text,
  new_status text,
  remarks text,
  created_at timestamp with time zone DEFAULT now(),
  CONSTRAINT audit_trails_pkey PRIMARY KEY (id),
  CONSTRAINT audit_trails_service_request_id_fkey FOREIGN KEY (service_request_id) REFERENCES public.service_requests(service_request_id),
  CONSTRAINT audit_trails_user_id_fkey FOREIGN KEY (user_id) REFERENCES public.users(userId)
);
CREATE TABLE public.operator_verified_services (
  verification_id uuid NOT NULL DEFAULT gen_random_uuid(),
  service_request_id uuid NOT NULL,
  operator_id uuid NOT NULL,
  verified_at timestamp with time zone NOT NULL DEFAULT now(),
  actual_sacks integer NOT NULL,
  condition character varying NOT NULL,
  state character varying NOT NULL,
  source character varying NOT NULL,
  is_accurate boolean NOT NULL DEFAULT true,
  correction_notes text,
  processing_estimate character varying,
  CONSTRAINT operator_verified_services_pkey PRIMARY KEY (verification_id),
  CONSTRAINT fk_verified_service_request FOREIGN KEY (service_request_id) REFERENCES public.service_requests(service_request_id),
  CONSTRAINT fk_verified_operator FOREIGN KEY (operator_id) REFERENCES public.users(userId)
);
CREATE TABLE public.mill_queue (
  queue_id uuid NOT NULL DEFAULT gen_random_uuid(),
  service_request_id uuid NOT NULL UNIQUE,
  queue_type character varying NOT NULL CHECK (queue_type::text = ANY (ARRAY['general'::character varying, 'scheduled'::character varying]::text[])),
  position integer NOT NULL DEFAULT nextval('mill_queue_position_seq'::regclass),
  scheduled_at timestamp with time zone,
  status character varying NOT NULL DEFAULT 'waiting'::character varying CHECK (status::text = ANY (ARRAY['waiting'::character varying, 'in_progress'::character varying, 'completed'::character varying, 'skipped'::character varying]::text[])),
  added_at timestamp with time zone DEFAULT now(),
  added_by uuid,
  CONSTRAINT mill_queue_pkey PRIMARY KEY (queue_id),
  CONSTRAINT mill_queue_added_by_fkey FOREIGN KEY (added_by) REFERENCES public.users(userId),
  CONSTRAINT fk_queue_service_request FOREIGN KEY (service_request_id) REFERENCES public.service_requests(service_request_id)
);
CREATE TABLE public.ongoing_services (
  id uuid NOT NULL DEFAULT gen_random_uuid(),
  service_request_id uuid NOT NULL UNIQUE,
  operator_id uuid NOT NULL,
  machine_id uuid,
  drum_id uuid,
  current_stage character varying NOT NULL DEFAULT 'rebagging'::character varying,
  started_at timestamp with time zone NOT NULL DEFAULT now(),
  last_stage_updated_at timestamp with time zone NOT NULL DEFAULT now(),
  remarks text,
  CONSTRAINT ongoing_services_pkey PRIMARY KEY (id),
  CONSTRAINT fk_ongoing_service_request FOREIGN KEY (service_request_id) REFERENCES public.service_requests(service_request_id),
  CONSTRAINT fk_ongoing_operator FOREIGN KEY (operator_id) REFERENCES public.users(userId),
  CONSTRAINT fk_ongoing_machine FOREIGN KEY (machine_id) REFERENCES public.machines(machine_id),
  CONSTRAINT fk_ongoing_drum FOREIGN KEY (drum_id) REFERENCES public.drums(drum_id)
);

CREATE TABLE public.milling_batches (
  batch_id uuid NOT NULL DEFAULT gen_random_uuid(),
  service_request_id uuid NOT NULL,
  operator_id uuid NOT NULL,
  machine_id uuid NOT NULL,
  drum_id uuid NOT NULL,
  input_sacks integer NOT NULL,
  output_sacks integer NOT NULL,
  estimated_duration_minutes integer,
  status character varying NOT NULL DEFAULT 'milling'::character varying CHECK (status::text = ANY (ARRAY['milling'::text, 'completed'::text])),
  created_at timestamp with time zone NOT NULL DEFAULT now(),
  completed_at timestamp with time zone,
  CONSTRAINT milling_batches_pkey PRIMARY KEY (batch_id),
  CONSTRAINT fk_mb_service_request FOREIGN KEY (service_request_id) REFERENCES public.service_requests(service_request_id),
  CONSTRAINT fk_mb_operator FOREIGN KEY (operator_id) REFERENCES public.users(userId),
  CONSTRAINT fk_mb_machine FOREIGN KEY (machine_id) REFERENCES public.machines(machine_id),
  CONSTRAINT fk_mb_drum FOREIGN KEY (drum_id) REFERENCES public.drums(drum_id)
);
