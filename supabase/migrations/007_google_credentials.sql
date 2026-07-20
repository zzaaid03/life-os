-- Migration 007: Google credentials (refresh tokens)
--
-- Stores each user's Google OAuth refresh token so the backend can mint a
-- fresh Gmail access token on demand — no more relying on the short-lived,
-- reload-losing session provider token. One row per user.
--
-- RLS: a user can only read/write their own row. The extract-tasks Edge
-- Function reads it with the service role (bypasses RLS) to mint tokens.
--
-- SECURITY: refresh tokens are sensitive. They are never exposed to other
-- users (RLS) and never returned to the client by any function.

CREATE TABLE IF NOT EXISTS public.google_credentials (
  user_id UUID PRIMARY KEY REFERENCES auth.users(id) ON DELETE CASCADE,
  refresh_token TEXT NOT NULL,
  scope TEXT,
  created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

ALTER TABLE public.google_credentials ENABLE ROW LEVEL SECURITY;

CREATE POLICY "Users manage own google credentials - select"
  ON public.google_credentials FOR SELECT
  USING (auth.uid() = user_id);

CREATE POLICY "Users manage own google credentials - insert"
  ON public.google_credentials FOR INSERT
  WITH CHECK (auth.uid() = user_id);

CREATE POLICY "Users manage own google credentials - update"
  ON public.google_credentials FOR UPDATE
  USING (auth.uid() = user_id)
  WITH CHECK (auth.uid() = user_id);

CREATE POLICY "Users manage own google credentials - delete"
  ON public.google_credentials FOR DELETE
  USING (auth.uid() = user_id);

CREATE OR REPLACE FUNCTION public.touch_google_credentials_updated_at()
RETURNS TRIGGER
LANGUAGE plpgsql
SECURITY DEFINER SET search_path = ''
AS $$
BEGIN
  NEW.updated_at = NOW();
  RETURN NEW;
END;
$$;

DROP TRIGGER IF EXISTS on_google_credentials_updated ON public.google_credentials;
CREATE TRIGGER on_google_credentials_updated
  BEFORE UPDATE ON public.google_credentials
  FOR EACH ROW
  EXECUTE FUNCTION public.touch_google_credentials_updated_at();
