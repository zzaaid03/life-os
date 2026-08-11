-- 018_subscriptions.sql
--
-- Recurring money: subscriptions, memberships and regular bills.
--
-- The widened inbox scan already extracts subscription renewals and bills,
-- but they became one-off tasks and the knowledge evaporated. This table is
-- where a recurring charge lives as a durable thing, so "what am I paying
-- for" is answerable.
--
-- Idempotent throughout (IF NOT EXISTS / DROP ... IF EXISTS): migrations in
-- this project get re-run.
--
-- Notes that are load-bearing, do not "simplify" them away:
--   * Amounts are INTEGER CENTS, never a float. Summing floats for a totals
--     screen produces 30.299999999999997.
--   * `currency` is stored per row and NEVER converted. Totals are grouped
--     per currency in application code; an FX rate would be invented data.
--   * RLS is not enough on its own. Raw-SQL tables in this project also need
--     explicit GRANTs or they throw 42501 permission denied. That has bitten
--     this codebase three times (see migrations 008/011).

CREATE TABLE IF NOT EXISTS public.subscriptions (
  id              UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id         UUID NOT NULL REFERENCES auth.users (id) ON DELETE CASCADE,

  name            TEXT NOT NULL,
  amount_cents    INTEGER NOT NULL,
  currency        TEXT NOT NULL DEFAULT 'USD',
  cycle           TEXT NOT NULL,
  next_charge_date DATE,

  status          TEXT NOT NULL DEFAULT 'active',
  notes           TEXT,

  -- Set when a row originated from an inbox scan (slice 2b), null when the
  -- user added it by hand. Also the dedup key for "already suggested this".
  source_email_id TEXT,

  created_at      TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  updated_at      TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  deleted_at      TIMESTAMPTZ
);

-- A charge cycle we can actually convert to a monthly equivalent.
ALTER TABLE public.subscriptions
  DROP CONSTRAINT IF EXISTS subscriptions_cycle_check;
ALTER TABLE public.subscriptions
  ADD CONSTRAINT subscriptions_cycle_check
  CHECK (cycle IN ('weekly', 'monthly', 'quarterly', 'yearly'));

ALTER TABLE public.subscriptions
  DROP CONSTRAINT IF EXISTS subscriptions_status_check;
ALTER TABLE public.subscriptions
  ADD CONSTRAINT subscriptions_status_check
  CHECK (status IN ('active', 'cancelled'));

-- A refund or credit is not a subscription; a negative charge would quietly
-- reduce the monthly total and make it wrong.
ALTER TABLE public.subscriptions
  DROP CONSTRAINT IF EXISTS subscriptions_amount_check;
ALTER TABLE public.subscriptions
  ADD CONSTRAINT subscriptions_amount_check
  CHECK (amount_cents >= 0);

-- Three-letter ISO code, stored uppercase so grouping by currency cannot
-- split 'usd' and 'USD' into two buckets.
ALTER TABLE public.subscriptions
  DROP CONSTRAINT IF EXISTS subscriptions_currency_check;
ALTER TABLE public.subscriptions
  ADD CONSTRAINT subscriptions_currency_check
  CHECK (currency ~ '^[A-Z]{3}$');

CREATE INDEX IF NOT EXISTS subscriptions_user_live_idx
  ON public.subscriptions (user_id, deleted_at, status);

CREATE INDEX IF NOT EXISTS subscriptions_user_next_charge_idx
  ON public.subscriptions (user_id, next_charge_date);

-- Stops the same scanned email creating the same subscription twice. Partial,
-- because a hand-added row has no source email and many may share that null.
CREATE UNIQUE INDEX IF NOT EXISTS subscriptions_user_source_email_idx
  ON public.subscriptions (user_id, source_email_id)
  WHERE source_email_id IS NOT NULL;

ALTER TABLE public.subscriptions ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS "Users read own subscriptions" ON public.subscriptions;
CREATE POLICY "Users read own subscriptions"
  ON public.subscriptions FOR SELECT
  USING (auth.uid() = user_id);

DROP POLICY IF EXISTS "Users insert own subscriptions" ON public.subscriptions;
CREATE POLICY "Users insert own subscriptions"
  ON public.subscriptions FOR INSERT
  WITH CHECK (auth.uid() = user_id);

DROP POLICY IF EXISTS "Users update own subscriptions" ON public.subscriptions;
CREATE POLICY "Users update own subscriptions"
  ON public.subscriptions FOR UPDATE
  USING (auth.uid() = user_id)
  WITH CHECK (auth.uid() = user_id);

DROP POLICY IF EXISTS "Users delete own subscriptions" ON public.subscriptions;
CREATE POLICY "Users delete own subscriptions"
  ON public.subscriptions FOR DELETE
  USING (auth.uid() = user_id);

-- RLS alone still returns 42501 without these. Do NOT add `anon` here; that
-- would open the table to unauthenticated writes from anyone holding the
-- publishable key, which ships in the public web bundle.
GRANT SELECT, INSERT, UPDATE, DELETE ON public.subscriptions
  TO authenticated, service_role;

CREATE OR REPLACE FUNCTION public.touch_subscriptions_updated_at()
RETURNS TRIGGER
LANGUAGE plpgsql
AS $$
BEGIN
  NEW.updated_at = NOW();
  RETURN NEW;
END;
$$;

DROP TRIGGER IF EXISTS on_subscriptions_updated ON public.subscriptions;
CREATE TRIGGER on_subscriptions_updated
  BEFORE UPDATE ON public.subscriptions
  FOR EACH ROW
  EXECUTE FUNCTION public.touch_subscriptions_updated_at();
