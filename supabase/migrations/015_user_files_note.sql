-- The user's one-line "what is this?" description, typed at upload time.
-- This is the primary search key: a photo has no text the AI can read, so
-- without a note a scanned passport and a scanned lease are indistinguishable
-- to search. Deliberately NO index: search is `ILIKE '%term%'`, which a
-- btree index cannot serve, and at a few dozen rows per user a sequential
-- scan is instant. Idempotent because migrations in this repo get re-run.
ALTER TABLE public.user_files
  ADD COLUMN IF NOT EXISTS user_note TEXT NOT NULL DEFAULT '';
