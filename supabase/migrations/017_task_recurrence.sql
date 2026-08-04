-- 017_task_recurrence.sql
-- Repeating tasks.
--
-- One nullable column. There is no series table: a recurring task has exactly
-- one live row at a time, and completing it spawns the next one client-side
-- (see lib/features/tasks/domain/recurrence.dart). NULL means "does not
-- repeat", which is every row that exists today.
--
-- Idempotent, like every migration in this project.

ALTER TABLE public.tasks
  ADD COLUMN IF NOT EXISTS recurrence text;

-- Constrain the vocabulary at the database rather than trusting the client.
-- Dropped first so re-running this file cannot fail on an existing constraint.
ALTER TABLE public.tasks
  DROP CONSTRAINT IF EXISTS tasks_recurrence_check;

ALTER TABLE public.tasks
  ADD CONSTRAINT tasks_recurrence_check
  CHECK (recurrence IS NULL OR recurrence IN ('daily', 'weekly', 'monthly'));

COMMENT ON COLUMN public.tasks.recurrence IS
  'daily | weekly | monthly, or NULL for a one-off task. A completed task '
  'gives up its rule to the occurrence it spawns, so completed + recurring '
  'should not co-exist on one row.';
