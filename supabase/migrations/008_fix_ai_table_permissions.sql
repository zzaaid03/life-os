-- Migration 008: Grant table privileges on the AI-feature tables
--
-- Tables created via raw SQL migrations (006 job_applications, 007
-- google_credentials) do NOT automatically grant privileges to the
-- `authenticated` role the way dashboard-created tables do. RLS policies
-- were in place, but without these GRANTs the authenticated role gets
-- "permission denied for table" (SQLSTATE 42501) on any access.
--
-- RLS still restricts each user to their own rows; these grants only allow
-- the role to reach the table at all.

-- authenticated: the app (user session) writes/reads its own rows (RLS-scoped).
-- service_role: the extract-tasks Edge Function reads credentials to mint tokens.
GRANT SELECT, INSERT, UPDATE, DELETE ON public.google_credentials TO authenticated, service_role;
GRANT SELECT, INSERT, UPDATE, DELETE ON public.job_applications TO authenticated, service_role;
