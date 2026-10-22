ALTER TABLE public.operator_verified_services
ADD COLUMN IF NOT EXISTS verification_photo_urls text[] NOT NULL DEFAULT '{}'::text[];
