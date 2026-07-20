-- Migration 011: service_role grants for the daily-brief Edge Function
--
-- The daily-brief function reads the user's tasks, job applications,
-- habits, habit entries, and goals server-side with the service role to
-- build an AI morning summary. Migration 004 granted these entity tables
-- to `authenticated` only; tables created via raw SQL don't automatically
-- grant to service_role, which would 42501 the function.

GRANT SELECT ON public.tasks TO service_role;
GRANT SELECT ON public.notes TO service_role;
GRANT SELECT ON public.goals TO service_role;
GRANT SELECT ON public.habits TO service_role;
GRANT SELECT ON public.habit_entries TO service_role;
