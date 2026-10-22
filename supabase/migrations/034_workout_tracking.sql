-- 034_workout_tracking.sql
--
-- Workout tracking: sessions (one run of a plan day), the sets logged in a
-- session, and a daily "did you train today?" check-in.
--
-- Idempotent throughout (IF NOT EXISTS / DROP ... IF EXISTS).
--
-- Notes:
--   * workout_sets has NO foreign key to workout_plan_exercises on purpose.
--     It stores the exercise name, so logs survive a deleted exercise.
--   * Sessions keep plan_id as ON DELETE SET NULL. The app only soft-deletes
--     plans, so this is a safety net, not a code path.
--   * Sets cascade with their session (hard-deleting a session removes its
--     sets). Sessions are not soft-deleted.
--   * INSERT/UPDATE policies on sets also check the session belongs to the
--     caller, so nobody can attach sets to someone else's session.
--   * Check-ins are one row per user per local day. The app never deletes
--     them, so there is no DELETE policy and no DELETE grant.
--   * RLS is not enough on its own, raw-SQL tables also need GRANTs.
--     Never grant to anon.

-- Sessions ---------------------------------------------------------------

CREATE TABLE IF NOT EXISTS public.workout_sessions (
  id            UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id       UUID NOT NULL REFERENCES auth.users (id),

  plan_id       UUID REFERENCES public.workout_plans (id) ON DELETE SET NULL,
  day_title     TEXT NOT NULL,
  day_position  INT NOT NULL,
  started_at    TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  ended_at      TIMESTAMPTZ,

  created_at    TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

ALTER TABLE public.workout_sessions
  DROP CONSTRAINT IF EXISTS workout_sessions_day_title_check;
ALTER TABLE public.workout_sessions
  ADD CONSTRAINT workout_sessions_day_title_check
  CHECK (length(day_title) BETWEEN 1 AND 40);

ALTER TABLE public.workout_sessions
  DROP CONSTRAINT IF EXISTS workout_sessions_day_position_check;
ALTER TABLE public.workout_sessions
  ADD CONSTRAINT workout_sessions_day_position_check
  CHECK (day_position BETWEEN 0 AND 6);

CREATE INDEX IF NOT EXISTS workout_sessions_user_started_idx
  ON public.workout_sessions (user_id, started_at DESC);

-- Sets -------------------------------------------------------------------

CREATE TABLE IF NOT EXISTS public.workout_sets (
  id             UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id        UUID NOT NULL REFERENCES auth.users (id),

  session_id     UUID NOT NULL
                   REFERENCES public.workout_sessions (id) ON DELETE CASCADE,
  exercise_name  TEXT NOT NULL,
  kind           TEXT NOT NULL,
  set_number     INT NOT NULL,
  reps           INT,
  weight_kg      NUMERIC(6, 2),
  hold_seconds   INT,
  logged_at      TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

ALTER TABLE public.workout_sets
  DROP CONSTRAINT IF EXISTS workout_sets_exercise_name_check;
ALTER TABLE public.workout_sets
  ADD CONSTRAINT workout_sets_exercise_name_check
  CHECK (length(exercise_name) BETWEEN 1 AND 60);

ALTER TABLE public.workout_sets
  DROP CONSTRAINT IF EXISTS workout_sets_kind_check;
ALTER TABLE public.workout_sets
  ADD CONSTRAINT workout_sets_kind_check
  CHECK (kind IN ('reps', 'time'));

ALTER TABLE public.workout_sets
  DROP CONSTRAINT IF EXISTS workout_sets_set_number_check;
ALTER TABLE public.workout_sets
  ADD CONSTRAINT workout_sets_set_number_check
  CHECK (set_number BETWEEN 1 AND 20);

ALTER TABLE public.workout_sets
  DROP CONSTRAINT IF EXISTS workout_sets_reps_check;
ALTER TABLE public.workout_sets
  ADD CONSTRAINT workout_sets_reps_check
  CHECK (reps IS NULL OR reps BETWEEN 1 AND 200);

ALTER TABLE public.workout_sets
  DROP CONSTRAINT IF EXISTS workout_sets_weight_check;
ALTER TABLE public.workout_sets
  ADD CONSTRAINT workout_sets_weight_check
  CHECK (weight_kg IS NULL OR weight_kg BETWEEN 0 AND 1000);

ALTER TABLE public.workout_sets
  DROP CONSTRAINT IF EXISTS workout_sets_hold_check;
ALTER TABLE public.workout_sets
  ADD CONSTRAINT workout_sets_hold_check
  CHECK (hold_seconds IS NULL OR hold_seconds BETWEEN 1 AND 3600);

-- reps rows need reps and no hold, time rows the reverse. Weight is allowed
-- for both.
ALTER TABLE public.workout_sets
  DROP CONSTRAINT IF EXISTS workout_sets_kind_fields_check;
ALTER TABLE public.workout_sets
  ADD CONSTRAINT workout_sets_kind_fields_check
  CHECK (
    (kind = 'reps' AND reps IS NOT NULL AND hold_seconds IS NULL)
    OR
    (kind = 'time' AND hold_seconds IS NOT NULL AND reps IS NULL)
  );

CREATE INDEX IF NOT EXISTS workout_sets_session_idx
  ON public.workout_sets (session_id);

CREATE INDEX IF NOT EXISTS workout_sets_user_exercise_logged_idx
  ON public.workout_sets (user_id, exercise_name, logged_at DESC);

-- Check-ins --------------------------------------------------------------

CREATE TABLE IF NOT EXISTS public.workout_checkins (
  user_id     UUID NOT NULL REFERENCES auth.users (id),

  local_date  DATE NOT NULL,
  trained     BOOLEAN NOT NULL,
  updated_at  TIMESTAMPTZ NOT NULL DEFAULT NOW(),

  PRIMARY KEY (user_id, local_date)
);

-- RLS --------------------------------------------------------------------

ALTER TABLE public.workout_sessions ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.workout_sets ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.workout_checkins ENABLE ROW LEVEL SECURITY;

-- workout_sessions

DROP POLICY IF EXISTS "Users read own workout sessions" ON public.workout_sessions;
CREATE POLICY "Users read own workout sessions"
  ON public.workout_sessions FOR SELECT
  TO authenticated
  USING (auth.uid() = user_id);

DROP POLICY IF EXISTS "Users insert own workout sessions" ON public.workout_sessions;
CREATE POLICY "Users insert own workout sessions"
  ON public.workout_sessions FOR INSERT
  TO authenticated
  WITH CHECK (auth.uid() = user_id);

DROP POLICY IF EXISTS "Users update own workout sessions" ON public.workout_sessions;
CREATE POLICY "Users update own workout sessions"
  ON public.workout_sessions FOR UPDATE
  TO authenticated
  USING (auth.uid() = user_id)
  WITH CHECK (auth.uid() = user_id);

DROP POLICY IF EXISTS "Users delete own workout sessions" ON public.workout_sessions;
CREATE POLICY "Users delete own workout sessions"
  ON public.workout_sessions FOR DELETE
  TO authenticated
  USING (auth.uid() = user_id);

-- workout_sets (parent: workout_sessions)

DROP POLICY IF EXISTS "Users read own workout sets" ON public.workout_sets;
CREATE POLICY "Users read own workout sets"
  ON public.workout_sets FOR SELECT
  TO authenticated
  USING (auth.uid() = user_id);

DROP POLICY IF EXISTS "Users insert own workout sets" ON public.workout_sets;
CREATE POLICY "Users insert own workout sets"
  ON public.workout_sets FOR INSERT
  TO authenticated
  WITH CHECK (
    auth.uid() = user_id
    AND EXISTS (
      SELECT 1 FROM public.workout_sessions s
      WHERE s.id = session_id AND s.user_id = auth.uid()
    )
  );

DROP POLICY IF EXISTS "Users update own workout sets" ON public.workout_sets;
CREATE POLICY "Users update own workout sets"
  ON public.workout_sets FOR UPDATE
  TO authenticated
  USING (auth.uid() = user_id)
  WITH CHECK (
    auth.uid() = user_id
    AND EXISTS (
      SELECT 1 FROM public.workout_sessions s
      WHERE s.id = session_id AND s.user_id = auth.uid()
    )
  );

DROP POLICY IF EXISTS "Users delete own workout sets" ON public.workout_sets;
CREATE POLICY "Users delete own workout sets"
  ON public.workout_sets FOR DELETE
  TO authenticated
  USING (auth.uid() = user_id);

-- workout_checkins (no delete)

DROP POLICY IF EXISTS "Users read own workout checkins" ON public.workout_checkins;
CREATE POLICY "Users read own workout checkins"
  ON public.workout_checkins FOR SELECT
  TO authenticated
  USING (auth.uid() = user_id);

DROP POLICY IF EXISTS "Users insert own workout checkins" ON public.workout_checkins;
CREATE POLICY "Users insert own workout checkins"
  ON public.workout_checkins FOR INSERT
  TO authenticated
  WITH CHECK (auth.uid() = user_id);

DROP POLICY IF EXISTS "Users update own workout checkins" ON public.workout_checkins;
CREATE POLICY "Users update own workout checkins"
  ON public.workout_checkins FOR UPDATE
  TO authenticated
  USING (auth.uid() = user_id)
  WITH CHECK (auth.uid() = user_id);

-- Grants -----------------------------------------------------------------

REVOKE ALL ON public.workout_sessions FROM anon;
REVOKE ALL ON public.workout_sets FROM anon;
REVOKE ALL ON public.workout_checkins FROM anon;

GRANT SELECT, INSERT, UPDATE, DELETE ON public.workout_sessions
  TO authenticated, service_role;
GRANT SELECT, INSERT, UPDATE, DELETE ON public.workout_sets
  TO authenticated, service_role;
GRANT SELECT, INSERT, UPDATE ON public.workout_checkins
  TO authenticated, service_role;
