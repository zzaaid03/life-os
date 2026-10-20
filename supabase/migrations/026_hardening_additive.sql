-- Migration 026: additive hardening (safe to run any time, removes no access).
--   1. Pin search_path on the four trigger functions that still lack it.
--   2. Add composite indexes for queries that filter on user_id plus another
--      column and had no matching index.
-- Idempotent: ALTER FUNCTION ... SET and CREATE INDEX IF NOT EXISTS can be re-run.

-- 1. search_path ---------------------------------------------------------
-- These bodies only use NEW and NOW() (pg_catalog), so an empty search_path
-- changes nothing about what they do.
ALTER FUNCTION public.touch_user_facts_updated_at() SET search_path = '';
ALTER FUNCTION public.touch_subscriptions_updated_at() SET search_path = '';
ALTER FUNCTION public.touch_grocery_items_updated_at() SET search_path = '';
ALTER FUNCTION public.touch_recipes_updated_at() SET search_path = '';

-- 2. Composite indexes ---------------------------------------------------
-- No CONCURRENTLY: the dashboard SQL editor runs the script in one transaction.

-- Needed by: supabase/functions/goal-breakdown (open tasks) and
-- supabase/functions/infer-facts (open and completed tasks):
-- WHERE user_id = ? AND deleted_at IS NULL ORDER BY created_at DESC.
CREATE INDEX IF NOT EXISTS tasks_user_created_live_idx
  ON public.tasks (user_id, created_at DESC)
  WHERE deleted_at IS NULL;

-- Needed by: lib SupabaseGoalRepository.getAll and
-- supabase/functions/infer-facts (active goals):
-- WHERE user_id = ? AND deleted_at IS NULL ORDER BY created_at.
CREATE INDEX IF NOT EXISTS goals_user_created_live_idx
  ON public.goals (user_id, created_at)
  WHERE deleted_at IS NULL;

-- Needed by: supabase/functions/infer-facts (recent job applications):
-- WHERE user_id = ? ORDER BY created_at DESC. The existing
-- job_applications_user_updated_idx only covers updated_at.
CREATE INDEX IF NOT EXISTS job_applications_user_created_idx
  ON public.job_applications (user_id, created_at DESC);
