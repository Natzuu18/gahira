ALTER TABLE public.operator_verification_appeals
  ADD COLUMN IF NOT EXISTS evidence_url text;

DO $$
BEGIN
  IF NOT EXISTS (
    SELECT 1
    FROM pg_constraint
    WHERE conname = 'operator_verification_appeals_evidence_url_check'
      AND conrelid = 'public.operator_verification_appeals'::regclass
  ) THEN
    ALTER TABLE public.operator_verification_appeals
      ADD CONSTRAINT operator_verification_appeals_evidence_url_check
      CHECK (evidence_url IS NOT NULL AND length(trim(evidence_url)) > 0)
      NOT VALID;
  END IF;
END $$;
