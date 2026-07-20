-- Migration 010: Support company-less job-application updates
--
-- A scan can produce a valid update (e.g. a rejection) whose company the AI
-- couldn't identify. Previously UNIQUE(user_id, company, role) meant a second
-- company-less row (company = '', role = '') would collide, so such updates
-- were dropped entirely. Replace the blanket constraint with two partial
-- unique indexes:
--   * rows WITH a company stay unique per (user_id, company, role)
--   * rows WITHOUT a company are unique per (user_id, source_email_id),
--     so re-scanning the same email updates rather than duplicates.
-- The app performs explicit select-then-insert/update against these
-- identities (PostgREST upsert cannot target partial indexes).

ALTER TABLE public.job_applications
  DROP CONSTRAINT IF EXISTS job_applications_user_id_company_role_key;

CREATE UNIQUE INDEX IF NOT EXISTS job_applications_identity_idx
  ON public.job_applications (user_id, company, role)
  WHERE company <> '';

CREATE UNIQUE INDEX IF NOT EXISTS job_applications_email_identity_idx
  ON public.job_applications (user_id, source_email_id)
  WHERE company = '' AND source_email_id IS NOT NULL;
