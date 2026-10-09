-- 019_grocery_items.sql
--
-- The grocery list: a plain checklist of things to buy.
--
-- Slice 1 of the groceries + recipes feature. Recipes (slice 2) will add
-- items to this list, but nothing here depends on recipes existing.
--
-- Idempotent throughout (IF NOT EXISTS / DROP ... IF EXISTS): migrations in
-- this project get re-run.
--
-- Notes that are load-bearing, do not "simplify" them away:
--   * Rows are HARD deleted, unlike tasks/goals/subscriptions. A bought item
--     has no history worth keeping, and "clear checked items" on a list used
--     several times a week would otherwise grow the table forever.
--   * `quantity` is free TEXT ("500 g", "2", "a bunch"), not a number. The
--     list is for a human reading it in a shop, and recipe amounts arrive
--     with mixed units that have no meaningful common numeric form.
--   * RLS is not enough on its own. Raw-SQL tables in this project also need
--     explicit GRANTs or they throw 42501 permission denied (see 008/011).

CREATE TABLE IF NOT EXISTS public.grocery_items (
  id          UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id     UUID NOT NULL REFERENCES auth.users (id) ON DELETE CASCADE,

  name        TEXT NOT NULL,
  quantity    TEXT,
  checked     BOOLEAN NOT NULL DEFAULT FALSE,

  created_at  TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  updated_at  TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

-- An empty name renders as a blank row nobody can identify.
ALTER TABLE public.grocery_items
  DROP CONSTRAINT IF EXISTS grocery_items_name_check;
ALTER TABLE public.grocery_items
  ADD CONSTRAINT grocery_items_name_check
  CHECK (length(btrim(name)) > 0);

CREATE INDEX IF NOT EXISTS grocery_items_user_idx
  ON public.grocery_items (user_id, checked, created_at);

ALTER TABLE public.grocery_items ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS "Users read own grocery items" ON public.grocery_items;
CREATE POLICY "Users read own grocery items"
  ON public.grocery_items FOR SELECT
  USING (auth.uid() = user_id);

DROP POLICY IF EXISTS "Users insert own grocery items" ON public.grocery_items;
CREATE POLICY "Users insert own grocery items"
  ON public.grocery_items FOR INSERT
  WITH CHECK (auth.uid() = user_id);

DROP POLICY IF EXISTS "Users update own grocery items" ON public.grocery_items;
CREATE POLICY "Users update own grocery items"
  ON public.grocery_items FOR UPDATE
  USING (auth.uid() = user_id)
  WITH CHECK (auth.uid() = user_id);

DROP POLICY IF EXISTS "Users delete own grocery items" ON public.grocery_items;
CREATE POLICY "Users delete own grocery items"
  ON public.grocery_items FOR DELETE
  USING (auth.uid() = user_id);

-- RLS alone still returns 42501 without these. Do NOT add `anon` here; the
-- publishable key ships in the public web bundle.
GRANT SELECT, INSERT, UPDATE, DELETE ON public.grocery_items
  TO authenticated, service_role;

CREATE OR REPLACE FUNCTION public.touch_grocery_items_updated_at()
RETURNS TRIGGER
LANGUAGE plpgsql
AS $$
BEGIN
  NEW.updated_at = NOW();
  RETURN NEW;
END;
$$;

DROP TRIGGER IF EXISTS on_grocery_items_updated ON public.grocery_items;
CREATE TRIGGER on_grocery_items_updated
  BEFORE UPDATE ON public.grocery_items
  FOR EACH ROW
  EXECUTE FUNCTION public.touch_grocery_items_updated_at();
