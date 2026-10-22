-- 033_workout_plans.sql
--
-- Saved AI workout plans: a plan has days, a day has exercises.
-- The plan is generated once, saved, and reused (no AI call per view).
--
-- Idempotent throughout (IF NOT EXISTS / DROP ... IF EXISTS / OR REPLACE).
--
-- Notes:
--   * Foreign keys have no ON DELETE CASCADE on purpose. The app soft-deletes
--     plans (deleted_at) and cascades to days and exercises in Dart.
--   * Only one active, non-deleted plan per user (partial unique index).
--   * (user_id, created_at) on plans backs the 3-per-day generation limit.
--   * Exercise positions are not unique: reordering rewrites them.
--   * Days and exercises carry user_id too. Their INSERT/UPDATE policies also
--     check the parent row belongs to the caller, so nobody can attach rows
--     to someone else's plan.
--   * RLS is not enough on its own, raw-SQL tables also need GRANTs.
--     Never grant to anon.

-- Plans ------------------------------------------------------------------

CREATE TABLE IF NOT EXISTS public.workout_plans (
  id          UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id     UUID NOT NULL REFERENCES auth.users (id),

  name        TEXT NOT NULL,
  inputs      JSONB NOT NULL DEFAULT '{}',
  is_active   BOOLEAN NOT NULL DEFAULT TRUE,
  deleted_at  TIMESTAMPTZ,

  created_at  TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  updated_at  TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

ALTER TABLE public.workout_plans
  DROP CONSTRAINT IF EXISTS workout_plans_name_check;
ALTER TABLE public.workout_plans
  ADD CONSTRAINT workout_plans_name_check
  CHECK (length(name) BETWEEN 1 AND 60);

CREATE UNIQUE INDEX IF NOT EXISTS workout_plans_one_active_idx
  ON public.workout_plans (user_id)
  WHERE is_active AND deleted_at IS NULL;

CREATE INDEX IF NOT EXISTS workout_plans_user_created_idx
  ON public.workout_plans (user_id, created_at);

-- Days -------------------------------------------------------------------

CREATE TABLE IF NOT EXISTS public.workout_plan_days (
  id          UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id     UUID NOT NULL REFERENCES auth.users (id),

  plan_id     UUID NOT NULL REFERENCES public.workout_plans (id),
  position    SMALLINT NOT NULL,
  title       TEXT NOT NULL,

  created_at  TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  updated_at  TIMESTAMPTZ NOT NULL DEFAULT NOW(),

  CONSTRAINT workout_plan_days_plan_position_key UNIQUE (plan_id, position)
);

ALTER TABLE public.workout_plan_days
  DROP CONSTRAINT IF EXISTS workout_plan_days_position_check;
ALTER TABLE public.workout_plan_days
  ADD CONSTRAINT workout_plan_days_position_check
  CHECK (position BETWEEN 0 AND 6);

ALTER TABLE public.workout_plan_days
  DROP CONSTRAINT IF EXISTS workout_plan_days_title_check;
ALTER TABLE public.workout_plan_days
  ADD CONSTRAINT workout_plan_days_title_check
  CHECK (length(title) BETWEEN 1 AND 40);

-- Exercises --------------------------------------------------------------

CREATE TABLE IF NOT EXISTS public.workout_plan_exercises (
  id            UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id       UUID NOT NULL REFERENCES auth.users (id),

  day_id        UUID NOT NULL REFERENCES public.workout_plan_days (id),
  position      SMALLINT NOT NULL,
  name          TEXT NOT NULL,
  kind          TEXT NOT NULL,
  sets          SMALLINT NOT NULL,
  reps_min      SMALLINT,
  reps_max      SMALLINT,
  hold_seconds  SMALLINT,
  rest_seconds  SMALLINT NOT NULL,
  note          TEXT,

  created_at    TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  updated_at    TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

ALTER TABLE public.workout_plan_exercises
  DROP CONSTRAINT IF EXISTS workout_plan_exercises_position_check;
ALTER TABLE public.workout_plan_exercises
  ADD CONSTRAINT workout_plan_exercises_position_check
  CHECK (position BETWEEN 0 AND 19);

ALTER TABLE public.workout_plan_exercises
  DROP CONSTRAINT IF EXISTS workout_plan_exercises_name_check;
ALTER TABLE public.workout_plan_exercises
  ADD CONSTRAINT workout_plan_exercises_name_check
  CHECK (length(name) BETWEEN 1 AND 60);

ALTER TABLE public.workout_plan_exercises
  DROP CONSTRAINT IF EXISTS workout_plan_exercises_kind_check;
ALTER TABLE public.workout_plan_exercises
  ADD CONSTRAINT workout_plan_exercises_kind_check
  CHECK (kind IN ('reps', 'time'));

ALTER TABLE public.workout_plan_exercises
  DROP CONSTRAINT IF EXISTS workout_plan_exercises_sets_check;
ALTER TABLE public.workout_plan_exercises
  ADD CONSTRAINT workout_plan_exercises_sets_check
  CHECK (sets BETWEEN 1 AND 10);

ALTER TABLE public.workout_plan_exercises
  DROP CONSTRAINT IF EXISTS workout_plan_exercises_reps_check;
ALTER TABLE public.workout_plan_exercises
  ADD CONSTRAINT workout_plan_exercises_reps_check
  CHECK (
    (reps_min IS NULL OR reps_min BETWEEN 1 AND 50)
    AND (reps_max IS NULL OR reps_max BETWEEN 1 AND 50)
    AND (reps_min IS NULL OR reps_max IS NULL OR reps_min <= reps_max)
  );

ALTER TABLE public.workout_plan_exercises
  DROP CONSTRAINT IF EXISTS workout_plan_exercises_hold_check;
ALTER TABLE public.workout_plan_exercises
  ADD CONSTRAINT workout_plan_exercises_hold_check
  CHECK (hold_seconds IS NULL OR hold_seconds BETWEEN 5 AND 300);

ALTER TABLE public.workout_plan_exercises
  DROP CONSTRAINT IF EXISTS workout_plan_exercises_rest_check;
ALTER TABLE public.workout_plan_exercises
  ADD CONSTRAINT workout_plan_exercises_rest_check
  CHECK (rest_seconds BETWEEN 0 AND 600);

ALTER TABLE public.workout_plan_exercises
  DROP CONSTRAINT IF EXISTS workout_plan_exercises_note_check;
ALTER TABLE public.workout_plan_exercises
  ADD CONSTRAINT workout_plan_exercises_note_check
  CHECK (note IS NULL OR length(note) <= 140);

-- reps rows need a rep range and no hold, time rows the reverse.
ALTER TABLE public.workout_plan_exercises
  DROP CONSTRAINT IF EXISTS workout_plan_exercises_kind_fields_check;
ALTER TABLE public.workout_plan_exercises
  ADD CONSTRAINT workout_plan_exercises_kind_fields_check
  CHECK (
    (kind = 'reps'
      AND reps_min IS NOT NULL AND reps_max IS NOT NULL
      AND hold_seconds IS NULL)
    OR
    (kind = 'time'
      AND hold_seconds IS NOT NULL
      AND reps_min IS NULL AND reps_max IS NULL)
  );

CREATE INDEX IF NOT EXISTS workout_plan_exercises_day_position_idx
  ON public.workout_plan_exercises (day_id, position);

-- RLS --------------------------------------------------------------------

ALTER TABLE public.workout_plans ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.workout_plan_days ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.workout_plan_exercises ENABLE ROW LEVEL SECURITY;

-- workout_plans

DROP POLICY IF EXISTS "Users read own workout plans" ON public.workout_plans;
CREATE POLICY "Users read own workout plans"
  ON public.workout_plans FOR SELECT
  TO authenticated
  USING (auth.uid() = user_id);

DROP POLICY IF EXISTS "Users insert own workout plans" ON public.workout_plans;
CREATE POLICY "Users insert own workout plans"
  ON public.workout_plans FOR INSERT
  TO authenticated
  WITH CHECK (auth.uid() = user_id);

DROP POLICY IF EXISTS "Users update own workout plans" ON public.workout_plans;
CREATE POLICY "Users update own workout plans"
  ON public.workout_plans FOR UPDATE
  TO authenticated
  USING (auth.uid() = user_id)
  WITH CHECK (auth.uid() = user_id);

DROP POLICY IF EXISTS "Users delete own workout plans" ON public.workout_plans;
CREATE POLICY "Users delete own workout plans"
  ON public.workout_plans FOR DELETE
  TO authenticated
  USING (auth.uid() = user_id);

-- workout_plan_days (parent: workout_plans)

DROP POLICY IF EXISTS "Users read own workout plan days" ON public.workout_plan_days;
CREATE POLICY "Users read own workout plan days"
  ON public.workout_plan_days FOR SELECT
  TO authenticated
  USING (auth.uid() = user_id);

DROP POLICY IF EXISTS "Users insert own workout plan days" ON public.workout_plan_days;
CREATE POLICY "Users insert own workout plan days"
  ON public.workout_plan_days FOR INSERT
  TO authenticated
  WITH CHECK (
    auth.uid() = user_id
    AND EXISTS (
      SELECT 1 FROM public.workout_plans p
      WHERE p.id = plan_id AND p.user_id = auth.uid()
    )
  );

DROP POLICY IF EXISTS "Users update own workout plan days" ON public.workout_plan_days;
CREATE POLICY "Users update own workout plan days"
  ON public.workout_plan_days FOR UPDATE
  TO authenticated
  USING (auth.uid() = user_id)
  WITH CHECK (
    auth.uid() = user_id
    AND EXISTS (
      SELECT 1 FROM public.workout_plans p
      WHERE p.id = plan_id AND p.user_id = auth.uid()
    )
  );

DROP POLICY IF EXISTS "Users delete own workout plan days" ON public.workout_plan_days;
CREATE POLICY "Users delete own workout plan days"
  ON public.workout_plan_days FOR DELETE
  TO authenticated
  USING (auth.uid() = user_id);

-- workout_plan_exercises (parent: workout_plan_days)

DROP POLICY IF EXISTS "Users read own workout plan exercises" ON public.workout_plan_exercises;
CREATE POLICY "Users read own workout plan exercises"
  ON public.workout_plan_exercises FOR SELECT
  TO authenticated
  USING (auth.uid() = user_id);

DROP POLICY IF EXISTS "Users insert own workout plan exercises" ON public.workout_plan_exercises;
CREATE POLICY "Users insert own workout plan exercises"
  ON public.workout_plan_exercises FOR INSERT
  TO authenticated
  WITH CHECK (
    auth.uid() = user_id
    AND EXISTS (
      SELECT 1 FROM public.workout_plan_days d
      WHERE d.id = day_id AND d.user_id = auth.uid()
    )
  );

DROP POLICY IF EXISTS "Users update own workout plan exercises" ON public.workout_plan_exercises;
CREATE POLICY "Users update own workout plan exercises"
  ON public.workout_plan_exercises FOR UPDATE
  TO authenticated
  USING (auth.uid() = user_id)
  WITH CHECK (
    auth.uid() = user_id
    AND EXISTS (
      SELECT 1 FROM public.workout_plan_days d
      WHERE d.id = day_id AND d.user_id = auth.uid()
    )
  );

DROP POLICY IF EXISTS "Users delete own workout plan exercises" ON public.workout_plan_exercises;
CREATE POLICY "Users delete own workout plan exercises"
  ON public.workout_plan_exercises FOR DELETE
  TO authenticated
  USING (auth.uid() = user_id);

-- Grants -----------------------------------------------------------------

REVOKE ALL ON public.workout_plans FROM anon;
REVOKE ALL ON public.workout_plan_days FROM anon;
REVOKE ALL ON public.workout_plan_exercises FROM anon;

GRANT SELECT, INSERT, UPDATE, DELETE ON public.workout_plans
  TO authenticated, service_role;
GRANT SELECT, INSERT, UPDATE, DELETE ON public.workout_plan_days
  TO authenticated, service_role;
GRANT SELECT, INSERT, UPDATE, DELETE ON public.workout_plan_exercises
  TO authenticated, service_role;

-- updated_at triggers ----------------------------------------------------
-- Bodies only use NEW and NOW(), so an empty search_path is safe.

CREATE OR REPLACE FUNCTION public.touch_workout_plans_updated_at()
RETURNS TRIGGER
LANGUAGE plpgsql
SET search_path = ''
AS $$
BEGIN
  NEW.updated_at = NOW();
  RETURN NEW;
END;
$$;

DROP TRIGGER IF EXISTS on_workout_plans_updated ON public.workout_plans;
CREATE TRIGGER on_workout_plans_updated
  BEFORE UPDATE ON public.workout_plans
  FOR EACH ROW
  EXECUTE FUNCTION public.touch_workout_plans_updated_at();

CREATE OR REPLACE FUNCTION public.touch_workout_plan_days_updated_at()
RETURNS TRIGGER
LANGUAGE plpgsql
SET search_path = ''
AS $$
BEGIN
  NEW.updated_at = NOW();
  RETURN NEW;
END;
$$;

DROP TRIGGER IF EXISTS on_workout_plan_days_updated ON public.workout_plan_days;
CREATE TRIGGER on_workout_plan_days_updated
  BEFORE UPDATE ON public.workout_plan_days
  FOR EACH ROW
  EXECUTE FUNCTION public.touch_workout_plan_days_updated_at();

CREATE OR REPLACE FUNCTION public.touch_workout_plan_exercises_updated_at()
RETURNS TRIGGER
LANGUAGE plpgsql
SET search_path = ''
AS $$
BEGIN
  NEW.updated_at = NOW();
  RETURN NEW;
END;
$$;

DROP TRIGGER IF EXISTS on_workout_plan_exercises_updated ON public.workout_plan_exercises;
CREATE TRIGGER on_workout_plan_exercises_updated
  BEFORE UPDATE ON public.workout_plan_exercises
  FOR EACH ROW
  EXECUTE FUNCTION public.touch_workout_plan_exercises_updated_at();

-- Save a generated plan in one transaction ---------------------------------
-- Archives the current active plan and inserts the new plan, its days and
-- exercises. If any row fails a CHECK the whole call rolls back, so the old
-- plan stays active. Runs as the caller, so RLS still applies.
-- p_days: [{"title": "Push A", "exercises": [{"name", "kind", "sets",
--   "reps_min", "reps_max", "hold_seconds", "rest_seconds", "note"}]}]

CREATE OR REPLACE FUNCTION public.save_generated_workout_plan(
  p_name   TEXT,
  p_inputs JSONB,
  p_days   JSONB
)
RETURNS UUID
LANGUAGE plpgsql
SECURITY INVOKER
SET search_path = ''
AS $$
DECLARE
  v_uid     UUID := auth.uid();
  v_plan_id UUID;
  v_day_id  UUID;
  v_day     JSONB;
  v_day_pos BIGINT;
  v_ex      JSONB;
  v_ex_pos  BIGINT;
BEGIN
  IF v_uid IS NULL THEN
    RAISE EXCEPTION 'not signed in' USING ERRCODE = '42501';
  END IF;
  IF jsonb_typeof(p_days) <> 'array' OR jsonb_array_length(p_days) = 0 THEN
    RAISE EXCEPTION 'plan has no days' USING ERRCODE = '22023';
  END IF;

  UPDATE public.workout_plans
     SET is_active = FALSE
   WHERE user_id = v_uid AND is_active AND deleted_at IS NULL;

  INSERT INTO public.workout_plans (user_id, name, inputs)
  VALUES (v_uid, p_name, COALESCE(p_inputs, '{}'))
  RETURNING id INTO v_plan_id;

  FOR v_day, v_day_pos IN
    SELECT value, ordinality FROM jsonb_array_elements(p_days) WITH ORDINALITY
  LOOP
    INSERT INTO public.workout_plan_days (user_id, plan_id, position, title)
    VALUES (v_uid, v_plan_id, v_day_pos - 1, v_day->>'title')
    RETURNING id INTO v_day_id;

    FOR v_ex, v_ex_pos IN
      SELECT value, ordinality
        FROM jsonb_array_elements(COALESCE(v_day->'exercises', '[]'))
        WITH ORDINALITY
    LOOP
      INSERT INTO public.workout_plan_exercises (
        user_id, day_id, position, name, kind, sets,
        reps_min, reps_max, hold_seconds, rest_seconds, note
      ) VALUES (
        v_uid, v_day_id, v_ex_pos - 1, v_ex->>'name', v_ex->>'kind',
        (v_ex->>'sets')::SMALLINT,
        (v_ex->>'reps_min')::SMALLINT,
        (v_ex->>'reps_max')::SMALLINT,
        (v_ex->>'hold_seconds')::SMALLINT,
        (v_ex->>'rest_seconds')::SMALLINT,
        v_ex->>'note'
      );
    END LOOP;
  END LOOP;

  RETURN v_plan_id;
END;
$$;

REVOKE ALL ON FUNCTION public.save_generated_workout_plan(TEXT, JSONB, JSONB)
  FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.save_generated_workout_plan(TEXT, JSONB, JSONB)
  TO authenticated, service_role;
