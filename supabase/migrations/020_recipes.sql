-- 020_recipes.sql
--
-- Saved AI recipes, plus the user's own food preferences line.
--
-- Idempotent throughout (IF NOT EXISTS / DROP ... IF EXISTS): migrations in
-- this project get re-run.
--
-- Notes that are load-bearing, do not "simplify" them away:
--   * The whole recipe lives in one JSONB `data` column. Its shape is owned
--     by the Dart `Recipe` model and the `recipe-chef` function together;
--     adding a field (say, a nutrition block) must not need a migration.
--     `title` and `emoji` are copied out only so a list can be read cheaply.
--   * Rows are HARD deleted. An unsaved recipe is gone too; there is no
--     history worth keeping.
--   * A recipe is only ever saved by an explicit tap (Zaid's call). Nothing
--     server-side inserts here.
--   * `food_preferences` is free text the USER writes ("vegetarian, no
--     mushrooms"). It is not inferred and not one of the learned user_facts.
--   * RLS is not enough on its own: raw-SQL tables also need GRANTs or they
--     throw 42501 (see 008/011). Never grant to `anon`.

ALTER TABLE public.profiles
  ADD COLUMN IF NOT EXISTS food_preferences TEXT;

-- Sent with every recipe request, so keep it a line, not an essay.
ALTER TABLE public.profiles
  DROP CONSTRAINT IF EXISTS profiles_food_preferences_check;
ALTER TABLE public.profiles
  ADD CONSTRAINT profiles_food_preferences_check
  CHECK (food_preferences IS NULL OR length(food_preferences) <= 300);

CREATE TABLE IF NOT EXISTS public.recipes (
  id              UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id         UUID NOT NULL REFERENCES auth.users (id) ON DELETE CASCADE,

  title           TEXT NOT NULL,
  emoji           TEXT NOT NULL DEFAULT '🍽️',
  data            JSONB NOT NULL,

  times_cooked    INTEGER NOT NULL DEFAULT 0,
  last_cooked_at  TIMESTAMPTZ,

  created_at      TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  updated_at      TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

ALTER TABLE public.recipes
  DROP CONSTRAINT IF EXISTS recipes_title_check;
ALTER TABLE public.recipes
  ADD CONSTRAINT recipes_title_check
  CHECK (length(btrim(title)) > 0);

ALTER TABLE public.recipes
  DROP CONSTRAINT IF EXISTS recipes_times_cooked_check;
ALTER TABLE public.recipes
  ADD CONSTRAINT recipes_times_cooked_check
  CHECK (times_cooked >= 0);

CREATE INDEX IF NOT EXISTS recipes_user_created_idx
  ON public.recipes (user_id, created_at DESC);

ALTER TABLE public.recipes ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS "Users read own recipes" ON public.recipes;
CREATE POLICY "Users read own recipes"
  ON public.recipes FOR SELECT
  USING (auth.uid() = user_id);

DROP POLICY IF EXISTS "Users insert own recipes" ON public.recipes;
CREATE POLICY "Users insert own recipes"
  ON public.recipes FOR INSERT
  WITH CHECK (auth.uid() = user_id);

DROP POLICY IF EXISTS "Users update own recipes" ON public.recipes;
CREATE POLICY "Users update own recipes"
  ON public.recipes FOR UPDATE
  USING (auth.uid() = user_id)
  WITH CHECK (auth.uid() = user_id);

DROP POLICY IF EXISTS "Users delete own recipes" ON public.recipes;
CREATE POLICY "Users delete own recipes"
  ON public.recipes FOR DELETE
  USING (auth.uid() = user_id);

GRANT SELECT, INSERT, UPDATE, DELETE ON public.recipes
  TO authenticated, service_role;

CREATE OR REPLACE FUNCTION public.touch_recipes_updated_at()
RETURNS TRIGGER
LANGUAGE plpgsql
AS $$
BEGIN
  NEW.updated_at = NOW();
  RETURN NEW;
END;
$$;

DROP TRIGGER IF EXISTS on_recipes_updated ON public.recipes;
CREATE TRIGGER on_recipes_updated
  BEFORE UPDATE ON public.recipes
  FOR EACH ROW
  EXECUTE FUNCTION public.touch_recipes_updated_at();
