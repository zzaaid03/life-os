-- Migration 004: Fix entity table permissions (Milestone 3)
--
-- Migration 002 created entity tables with correct RLS policies,
-- but table-level privileges were never granted to the authenticated
-- role. Without these grants, every query returns "permission denied
-- (42501)" regardless of RLS policies.
--
-- This migration MUST be run after 002_create_entity_tables.sql.
-- It is safe to skip if 002 has not yet been applied.
--
-- No existing data is affected. All operations are additive and
-- idempotent (safe to re-run).

GRANT USAGE ON SCHEMA public TO anon, authenticated;

GRANT SELECT, INSERT, UPDATE, DELETE ON public.tasks TO authenticated;
GRANT SELECT, INSERT, UPDATE, DELETE ON public.notes TO authenticated;
GRANT SELECT, INSERT, UPDATE, DELETE ON public.goals TO authenticated;
GRANT SELECT, INSERT, UPDATE, DELETE ON public.habits TO authenticated;
GRANT SELECT, INSERT, UPDATE, DELETE ON public.habit_entries TO authenticated;
GRANT SELECT, INSERT, UPDATE, DELETE ON public.journal_entries TO authenticated;
GRANT SELECT, INSERT, UPDATE, DELETE ON public.tags TO authenticated;
GRANT SELECT, INSERT, UPDATE, DELETE ON public.entity_tags TO authenticated;
GRANT SELECT, INSERT, UPDATE, DELETE ON public.attachments TO authenticated;
GRANT SELECT, INSERT, UPDATE, DELETE ON public.sync_queue TO authenticated;
