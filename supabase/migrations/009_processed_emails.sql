-- Migration 009: Processed-email tracking for inbox scans
--
-- Records which Gmail message ids have already been surfaced as task
-- suggestions, so re-scanning the same inbox never re-suggests a task the
-- user has already added or dismissed. Only the opaque Gmail message id is
-- stored — never any email content.

CREATE TABLE IF NOT EXISTS public.processed_emails (
  user_id UUID NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
  email_id TEXT NOT NULL,
  created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  PRIMARY KEY (user_id, email_id)
);

ALTER TABLE public.processed_emails ENABLE ROW LEVEL SECURITY;

CREATE POLICY "Users can view own processed emails"
  ON public.processed_emails FOR SELECT
  USING (auth.uid() = user_id);

CREATE POLICY "Users can insert own processed emails"
  ON public.processed_emails FOR INSERT
  WITH CHECK (auth.uid() = user_id);

CREATE POLICY "Users can update own processed emails"
  ON public.processed_emails FOR UPDATE
  USING (auth.uid() = user_id)
  WITH CHECK (auth.uid() = user_id);

CREATE POLICY "Users can delete own processed emails"
  ON public.processed_emails FOR DELETE
  USING (auth.uid() = user_id);

-- Keep updated_at fresh on every update.
CREATE OR REPLACE FUNCTION public.touch_processed_emails_updated_at()
RETURNS TRIGGER
LANGUAGE plpgsql
SECURITY DEFINER SET search_path = ''
AS $$
BEGIN
  NEW.updated_at = NOW();
  RETURN NEW;
END;
$$;

DROP TRIGGER IF EXISTS on_processed_emails_updated ON public.processed_emails;
CREATE TRIGGER on_processed_emails_updated
  BEFORE UPDATE ON public.processed_emails
  FOR EACH ROW
  EXECUTE FUNCTION public.touch_processed_emails_updated_at();

-- Essential: without these grants the authenticated role gets
-- "permission denied" (SQLSTATE 42501) even with RLS policies in place.
GRANT SELECT, INSERT, UPDATE, DELETE ON public.processed_emails TO authenticated, service_role;
