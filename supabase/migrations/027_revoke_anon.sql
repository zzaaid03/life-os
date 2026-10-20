-- Migration 027: take every table and function privilege away from the anon role.
-- The app only talks to the database as a signed-in user (authenticated) or
-- from edge functions (service_role). The one anon grant that mattered was
-- SELECT on profiles from 003. RLS already hid the rows, this removes the grant.
-- supabase_auth_admin keeps EXECUTE on handle_new_user(), sign-up needs it.
-- USAGE ON SCHEMA public and PUBLIC grants are left alone on purpose.
-- REVOKE is idempotent, safe to re-run.

REVOKE SELECT ON public.profiles FROM anon;
REVOKE EXECUTE ON FUNCTION public.handle_new_user() FROM anon, authenticated;

REVOKE ALL ON public.profiles FROM anon;
REVOKE ALL ON public.tasks FROM anon;
REVOKE ALL ON public.notes FROM anon;
REVOKE ALL ON public.goals FROM anon;
REVOKE ALL ON public.habits FROM anon;
REVOKE ALL ON public.habit_entries FROM anon;
REVOKE ALL ON public.journal_entries FROM anon;
REVOKE ALL ON public.tags FROM anon;
REVOKE ALL ON public.entity_tags FROM anon;
REVOKE ALL ON public.attachments FROM anon;
REVOKE ALL ON public.sync_queue FROM anon;
REVOKE ALL ON public.job_applications FROM anon;
REVOKE ALL ON public.google_credentials FROM anon;
REVOKE ALL ON public.processed_emails FROM anon;
REVOKE ALL ON public.user_files FROM anon;
REVOKE ALL ON public.user_facts FROM anon;
REVOKE ALL ON public.subscriptions FROM anon;
REVOKE ALL ON public.grocery_items FROM anon;
REVOKE ALL ON public.recipes FROM anon;
REVOKE ALL ON public.ai_usage FROM anon;
