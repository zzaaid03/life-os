-- 028: remember when an email last changed a job's status.
-- Additive and idempotent. The app only moves a status forward from an email
-- and shows "Updated from email" while this is set; a manual edit clears it.
-- job_applications has table-level grants (008), so the new column is covered.
ALTER TABLE public.job_applications
  ADD COLUMN IF NOT EXISTS status_from_email_at timestamptz;
