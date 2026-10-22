-- 032: "lose weight" gets a pace.
--
-- lose_slow = 0.25 kg a week, lose = 0.5 kg a week (what an existing 'lose'
-- row now means), lose_fast = 0.75 kg a week. The kcal math stays in Dart.
-- Only widens the CHECK from 030, so every existing row still passes.
-- Idempotent: safe to re-run.

ALTER TABLE public.profiles DROP CONSTRAINT IF EXISTS profiles_calorie_goal_check;
ALTER TABLE public.profiles ADD CONSTRAINT profiles_calorie_goal_check
  CHECK (calorie_goal IS NULL OR calorie_goal IN
    ('lose_slow', 'lose', 'lose_fast', 'maintain', 'gain'));
