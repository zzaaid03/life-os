-- 035_packages.sql
--
-- Packages: things the user ordered that get shipped. Status comes from
-- emails only (the inbox scan), there is no carrier API.
--
-- Idempotent throughout (IF NOT EXISTS / DROP ... IF EXISTS / OR REPLACE):
-- migrations in this project get re-run.
--
-- Notes that are load-bearing, do not "simplify" them away:
--   * A row is matched by ONE identifier: tracking number first, else order
--     number. The CHECK below guarantees at least one exists.
--   * Soft-deleted rows keep their tracking number in the unique index on
--     purpose, so a later email for a deleted package matches it instead of
--     bringing it back as a new row.
--   * Raw-SQL tables need explicit GRANTs or they throw 42501. Never grant
--     to anon: the publishable key ships in the public web bundle.

CREATE TABLE IF NOT EXISTS public.packages (
  id              UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id         UUID NOT NULL REFERENCES auth.users (id) ON DELETE CASCADE,

  merchant        TEXT,
  item            TEXT,
  carrier         TEXT,
  tracking_number TEXT,
  order_number    TEXT,

  status          TEXT NOT NULL DEFAULT 'ordered',
  expected_date   DATE,
  delivered_at    TIMESTAMPTZ,
  last_update     TEXT,

  source_email_id TEXT,
  last_email_at   TIMESTAMPTZ,

  deleted_at      TIMESTAMPTZ,
  created_at      TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  updated_at      TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

ALTER TABLE public.packages DROP CONSTRAINT IF EXISTS packages_status_check;
ALTER TABLE public.packages
  ADD CONSTRAINT packages_status_check
  CHECK (status IN ('ordered', 'shipped', 'out_for_delivery', 'delivered'));

ALTER TABLE public.packages DROP CONSTRAINT IF EXISTS packages_lengths_check;
ALTER TABLE public.packages
  ADD CONSTRAINT packages_lengths_check
  CHECK (
    length(merchant) <= 120
    AND length(item) <= 200
    AND length(carrier) <= 60
    AND length(tracking_number) <= 60
    AND length(order_number) <= 60
    AND length(last_update) <= 300
  );

ALTER TABLE public.packages DROP CONSTRAINT IF EXISTS packages_identifier_check;
ALTER TABLE public.packages
  ADD CONSTRAINT packages_identifier_check
  CHECK (tracking_number IS NOT NULL OR order_number IS NOT NULL);

CREATE UNIQUE INDEX IF NOT EXISTS packages_user_tracking_idx
  ON public.packages (user_id, tracking_number)
  WHERE tracking_number IS NOT NULL;

CREATE INDEX IF NOT EXISTS packages_user_order_idx
  ON public.packages (user_id, order_number)
  WHERE order_number IS NOT NULL;

CREATE INDEX IF NOT EXISTS packages_user_live_idx
  ON public.packages (user_id, deleted_at, status);

ALTER TABLE public.packages ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS "Users read own packages" ON public.packages;
CREATE POLICY "Users read own packages"
  ON public.packages FOR SELECT
  USING (auth.uid() = user_id);

DROP POLICY IF EXISTS "Users insert own packages" ON public.packages;
CREATE POLICY "Users insert own packages"
  ON public.packages FOR INSERT
  WITH CHECK (auth.uid() = user_id);

DROP POLICY IF EXISTS "Users update own packages" ON public.packages;
CREATE POLICY "Users update own packages"
  ON public.packages FOR UPDATE
  USING (auth.uid() = user_id)
  WITH CHECK (auth.uid() = user_id);

DROP POLICY IF EXISTS "Users delete own packages" ON public.packages;
CREATE POLICY "Users delete own packages"
  ON public.packages FOR DELETE
  USING (auth.uid() = user_id);

REVOKE ALL ON public.packages FROM anon;
GRANT SELECT, INSERT, UPDATE, DELETE ON public.packages
  TO authenticated, service_role;

-- Only uses NEW and NOW() (pg_catalog), so an empty search_path changes nothing.
CREATE OR REPLACE FUNCTION public.touch_packages_updated_at()
RETURNS TRIGGER
LANGUAGE plpgsql
SET search_path = ''
AS $$
BEGIN
  NEW.updated_at = NOW();
  RETURN NEW;
END;
$$;

DROP TRIGGER IF EXISTS on_packages_updated ON public.packages;
CREATE TRIGGER on_packages_updated
  BEFORE UPDATE ON public.packages
  FOR EACH ROW
  EXECUTE FUNCTION public.touch_packages_updated_at();
