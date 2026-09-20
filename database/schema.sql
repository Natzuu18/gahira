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
  status character varying NOT NULL DEFAULT 'pending'::character varying CHECK (status::text = ANY (ARRAY['draft'::text, 'pending'::text, 'pendingOperatorVerification'::text, 'returnedToMiner'::text, 'accepted'::text, 'verified'::text, 'scheduled'::text, 'assigned'::text, 'processing'::text, 'processingCompleted'::text, 'goldHandoff'::text, 'completed'::text, 'cancelled'::text])),
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
  sacked_quantity integer,
  billing_id text,
  CONSTRAINT service_requests_pkey PRIMARY KEY (service_request_id),
  CONSTRAINT fk_service_request_user FOREIGN KEY (user_id) REFERENCES public.users(userId),
  CONSTRAINT fk_service_request_availability FOREIGN KEY (service_availability_id) REFERENCES public.service_availability(service_availability_id),
  CONSTRAINT fk_service_request_approved_by FOREIGN KEY (approved_by) REFERENCES public.users(userId),
  CONSTRAINT service_requests_assisted_by_operator_id_fkey FOREIGN KEY (assisted_by_operator_id) REFERENCES public.users(userId)
);

CREATE TABLE public.ongoing_services (
  id uuid NOT NULL DEFAULT gen_random_uuid(),
  service_request_id uuid NOT NULL,
  operator_id uuid NOT NULL,
  current_stage text NOT NULL DEFAULT 'rebagging'::text,
  started_at timestamp with time zone DEFAULT now(),
  updated_at timestamp with time zone DEFAULT now(),
  CONSTRAINT ongoing_services_pkey PRIMARY KEY (id),
  CONSTRAINT ongoing_services_service_request_id_fkey FOREIGN KEY (service_request_id) REFERENCES public.service_requests(service_request_id),
  CONSTRAINT ongoing_services_operator_id_fkey FOREIGN KEY (operator_id) REFERENCES public.users(userId)
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

CREATE TABLE public.processing_tasks (
    processing_id uuid NOT NULL DEFAULT gen_random_uuid(),
    service_request_id uuid REFERENCES public.service_requests(service_request_id),
    machine_id uuid REFERENCES public.machines(machine_id),
    drum_id uuid REFERENCES public.drums(drum_id),
    operator_id uuid REFERENCES public.users(userId),
    scheduled_date date NOT NULL,
    status text NOT NULL DEFAULT 'Scheduled',
    remarks text,
    created_at timestamp with time zone NOT NULL DEFAULT now(),
    updated_at timestamp with time zone NOT NULL DEFAULT now(),
    CONSTRAINT processing_tasks_pkey PRIMARY KEY (processing_id)
);
