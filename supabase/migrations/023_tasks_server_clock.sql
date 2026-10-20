-- 023_tasks_server_clock.sql
--
-- The server, not the device, now sets tasks.updated_at.
--
-- Native sync will use the newest server updated_at it has seen as its
-- watermark. Until now the client wrote updated_at from the device clock, so a
-- phone with a wrong clock could hide or replay changes. A trigger overrides
-- whatever the client sends, on both INSERT and UPDATE.
--
-- The index serves the sync pull: "my rows newer than the watermark, in order".
--
-- Idempotent throughout (CREATE OR REPLACE / DROP ... IF EXISTS / IF NOT
-- EXISTS): migrations in this project get re-run.

CREATE OR REPLACE FUNCTION public.touch_tasks_updated_at()
RETURNS TRIGGER
LANGUAGE plpgsql
SET search_path = ''
AS $$
BEGIN
  NEW.updated_at := now();
  RETURN NEW;
END;
$$;

DROP TRIGGER IF EXISTS on_tasks_updated ON public.tasks;
CREATE TRIGGER on_tasks_updated
  BEFORE INSERT OR UPDATE ON public.tasks
  FOR EACH ROW
  EXECUTE FUNCTION public.touch_tasks_updated_at();

CREATE INDEX IF NOT EXISTS idx_tasks_user_updated
  ON public.tasks (user_id, updated_at, id);
