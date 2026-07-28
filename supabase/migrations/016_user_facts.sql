-- 016_user_facts.sql
--
-- The learning system's storage: durable facts the AI has inferred about a
-- user from their own rows (tasks, goals, job applications, file notes).
--
-- Three properties of this table are load-bearing and should not be relaxed
-- without a deliberate decision:
--
--  1. `evidence` is NOT NULL. A fact that cannot be tied back to real rows is
--     an invention, and the job-application extractor already taught us what
--     happens when the model is allowed to assert things nothing supports.
--     The Settings mirror shows this column, so a wrong inference is
--     diagnosable instead of merely visible.
--
--  2. `suppressed_at` makes a user's deletion PERMANENT. The inference
--     function upserts on (user_id, fact_key) and must never clear this
--     column, so re-deriving a suppressed fact quietly bumps its timestamps
--     and it stays hidden forever. Without this, deleting a wrong fact would
--     be undone by the next run.
--
--  3. `fact_key` is a normalised dedupe key (lowercased, punctuation
--     stripped) written by the caller. It exists so a daily run cannot
--     accumulate forty near-identical rows saying the same thing.
--
-- Idempotent: safe to re-run.

CREATE TABLE IF NOT EXISTS public.user_facts (
  id           UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id      UUID NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,

  -- One of four fixed buckets. Free-form categories let the model drift into
  -- filler like "is a productive person"; a closed set keeps the mirror
  -- scannable and the inference prompt honest.
  category     TEXT NOT NULL
               CHECK (category IN ('routine', 'preference', 'situation', 'constraint')),

  -- The fact itself, one short sentence, written for the user to read.
  fact         TEXT NOT NULL CHECK (char_length(fact) BETWEEN 1 AND 200),

  -- What in the user's own data produced this. Shown in Settings.
  evidence     TEXT NOT NULL CHECK (char_length(evidence) BETWEEN 1 AND 400),

  -- Normalised form of `fact`, used only for deduplication.
  fact_key     TEXT NOT NULL CHECK (char_length(fact_key) BETWEEN 1 AND 200),

  first_seen_at     TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  last_confirmed_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),

  -- Set when the user says "that's not right". Never cleared by inference.
  suppressed_at     TIMESTAMPTZ,

  created_at   TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  updated_at   TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

-- One row per distinct fact per user. This is what makes the upsert work.
CREATE UNIQUE INDEX IF NOT EXISTS user_facts_user_key_idx
  ON public.user_facts (user_id, fact_key);

-- The mirror's only query: this user's live facts, newest confirmation first.
CREATE INDEX IF NOT EXISTS user_facts_user_live_idx
  ON public.user_facts (user_id, suppressed_at, last_confirmed_at DESC);

ALTER TABLE public.user_facts ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS "Users read own facts" ON public.user_facts;
CREATE POLICY "Users read own facts"
  ON public.user_facts FOR SELECT
  USING (auth.uid() = user_id);

DROP POLICY IF EXISTS "Users insert own facts" ON public.user_facts;
CREATE POLICY "Users insert own facts"
  ON public.user_facts FOR INSERT
  WITH CHECK (auth.uid() = user_id);

DROP POLICY IF EXISTS "Users update own facts" ON public.user_facts;
CREATE POLICY "Users update own facts"
  ON public.user_facts FOR UPDATE
  USING (auth.uid() = user_id)
  WITH CHECK (auth.uid() = user_id);

DROP POLICY IF EXISTS "Users delete own facts" ON public.user_facts;
CREATE POLICY "Users delete own facts"
  ON public.user_facts FOR DELETE
  USING (auth.uid() = user_id);

-- RLS is not a grant. Raw-SQL tables need this explicitly or every query
-- throws 42501 permission denied; that has bitten this project three times.
-- service_role is included so the inference Edge Function can write.
GRANT SELECT, INSERT, UPDATE, DELETE ON public.user_facts
  TO authenticated, service_role;

-- Keep updated_at fresh on every update.
CREATE OR REPLACE FUNCTION public.touch_user_facts_updated_at()
RETURNS TRIGGER
LANGUAGE plpgsql
AS $$
BEGIN
  NEW.updated_at = NOW();
  RETURN NEW;
END;
$$;

DROP TRIGGER IF EXISTS on_user_facts_updated ON public.user_facts;
CREATE TRIGGER on_user_facts_updated
  BEFORE UPDATE ON public.user_facts
  FOR EACH ROW
  EXECUTE FUNCTION public.touch_user_facts_updated_at();
