-- 030: inputs for the daily calorie target (round 8b).
--
-- The target itself is never stored. Dart computes it (Mifflin-St Jeor plus
-- the goal offset) from these columns every time, so changing the formula
-- later needs no backfill.
--   * Everything is nullable: no target until the user fills the form in.
--   * Stored metric. unit_system only decides how the app displays it.
--   * birth_year instead of age, so the target stays right after a birthday.
--   * profiles already has RLS (own row) and grants to authenticated and
--     service_role (anon was revoked in 027), so new columns need no GRANT.
-- Idempotent: safe to re-run.

ALTER TABLE public.profiles
  ADD COLUMN IF NOT EXISTS weight_kg      NUMERIC(5,1),
  ADD COLUMN IF NOT EXISTS height_cm      NUMERIC(4,1),
  ADD COLUMN IF NOT EXISTS birth_year     SMALLINT,
  ADD COLUMN IF NOT EXISTS sex            TEXT,
  ADD COLUMN IF NOT EXISTS activity_level TEXT,
  ADD COLUMN IF NOT EXISTS calorie_goal   TEXT,
  ADD COLUMN IF NOT EXISTS unit_system    TEXT;

-- Wide sanity ranges. The app validates tighter (age 13 to 100).
ALTER TABLE public.profiles DROP CONSTRAINT IF EXISTS profiles_weight_kg_check;
ALTER TABLE public.profiles ADD CONSTRAINT profiles_weight_kg_check
  CHECK (weight_kg IS NULL OR weight_kg BETWEEN 20 AND 400);

ALTER TABLE public.profiles DROP CONSTRAINT IF EXISTS profiles_height_cm_check;
ALTER TABLE public.profiles ADD CONSTRAINT profiles_height_cm_check
  CHECK (height_cm IS NULL OR height_cm BETWEEN 100 AND 250);

ALTER TABLE public.profiles DROP CONSTRAINT IF EXISTS profiles_birth_year_check;
ALTER TABLE public.profiles ADD CONSTRAINT profiles_birth_year_check
  CHECK (birth_year IS NULL OR birth_year BETWEEN 1900 AND 2100);

ALTER TABLE public.profiles DROP CONSTRAINT IF EXISTS profiles_sex_check;
ALTER TABLE public.profiles ADD CONSTRAINT profiles_sex_check
  CHECK (sex IS NULL OR sex IN ('male', 'female'));

ALTER TABLE public.profiles DROP CONSTRAINT IF EXISTS profiles_activity_level_check;
ALTER TABLE public.profiles ADD CONSTRAINT profiles_activity_level_check
  CHECK (activity_level IS NULL OR activity_level IN
    ('sedentary', 'light', 'moderate', 'active', 'very_active'));

ALTER TABLE public.profiles DROP CONSTRAINT IF EXISTS profiles_calorie_goal_check;
ALTER TABLE public.profiles ADD CONSTRAINT profiles_calorie_goal_check
  CHECK (calorie_goal IS NULL OR calorie_goal IN ('lose', 'maintain', 'gain'));

ALTER TABLE public.profiles DROP CONSTRAINT IF EXISTS profiles_unit_system_check;
ALTER TABLE public.profiles ADD CONSTRAINT profiles_unit_system_check
  CHECK (unit_system IS NULL OR unit_system IN ('metric', 'imperial'));
