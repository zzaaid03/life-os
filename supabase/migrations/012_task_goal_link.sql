-- Migration 012: link tasks to goals (AI Goal Breakdown)
--
-- Adds an optional goal_id FK on tasks so a goal's AI-generated tasks can be
-- tracked back to it, and goal progress can be derived from task completion.
-- Table grants for public.tasks already cover authenticated (004) and
-- service_role (011) at the table level, so no new GRANTs are needed for a
-- column addition.

ALTER TABLE public.tasks
  ADD COLUMN IF NOT EXISTS goal_id UUID REFERENCES public.goals(id) ON DELETE CASCADE;

CREATE INDEX IF NOT EXISTS idx_tasks_goal_id ON public.tasks(goal_id);
