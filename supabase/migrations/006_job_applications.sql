-- Migration 006: Job applications tracker
--
-- Stores one row per job application, populated by the inbox-AI scan.
-- Each scan UPSERTs on (user_id, company, role) so a new email advances the
-- status (applied -> viewed -> rejected/interview/offer) instead of creating
-- a duplicate row. We store only derived data (company/role/status/summary) —
-- never the raw email content.
--
-- RLS ensures each user can only see and modify their own applications.

CREATE TABLE IF NOT EXISTS public.job_applications (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id UUID NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
  company TEXT NOT NULL,
  role TEXT NOT NULL DEFAULT '',
  location TEXT,
  status TEXT NOT NULL DEFAULT 'applied',
  summary TEXT,
  source_email_id TEXT,
  applied_at DATE,
  created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  UNIQUE (user_id, company, role)
);

-- Fast lookups of a user's pipeline, newest first.
CREATE INDEX IF NOT EXISTS job_applications_user_updated_idx
  ON public.job_applications (user_id, updated_at DESC);

ALTER TABLE public.job_applications ENABLE ROW LEVEL SECURITY;

CREATE POLICY "Users can view own job applications"
  ON public.job_applications FOR SELECT
  USING (auth.uid() = user_id);

CREATE POLICY "Users can insert own job applications"
  ON public.job_applications FOR INSERT
  WITH CHECK (auth.uid() = user_id);

CREATE POLICY "Users can update own job applications"
  ON public.job_applications FOR UPDATE
  USING (auth.uid() = user_id)
  WITH CHECK (auth.uid() = user_id);

CREATE POLICY "Users can delete own job applications"
  ON public.job_applications FOR DELETE
  USING (auth.uid() = user_id);

-- Keep updated_at fresh on every update.
CREATE OR REPLACE FUNCTION public.touch_job_applications_updated_at()
RETURNS TRIGGER
LANGUAGE plpgsql
SECURITY DEFINER SET search_path = ''
AS $$
BEGIN
  NEW.updated_at = NOW();
  RETURN NEW;
END;
$$;

DROP TRIGGER IF EXISTS on_job_applications_updated ON public.job_applications;
CREATE TRIGGER on_job_applications_updated
  BEFORE UPDATE ON public.job_applications
  FOR EACH ROW
  EXECUTE FUNCTION public.touch_job_applications_updated_at();
