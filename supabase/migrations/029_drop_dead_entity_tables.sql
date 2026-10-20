-- 029: drop the unused tables from 002 (notes, habits, habit entries, journal,
-- tags, attachments, sync queue). Nothing in the app or the functions reads them
-- since Notes, Habits and Journal were removed.
--
-- Safety: refuses to run if any of them still holds a row, so this can never
-- delete real data. The one exception is a single leftover test note in notes,
-- checked by hand on 2026-10-20. A second note still stops it.
-- No CASCADE, so it also fails loudly if something new has
-- started depending on one of them. Policies, triggers and indexes go with the
-- tables. Safe to re-run (IF EXISTS).

DO $$
DECLARE
  t TEXT;
  n BIGINT;
BEGIN
  FOREACH t IN ARRAY ARRAY['notes', 'habits', 'habit_entries', 'journal_entries',
                           'tags', 'entity_tags', 'attachments', 'sync_queue'] LOOP
    IF to_regclass('public.' || t) IS NOT NULL THEN
      EXECUTE format('SELECT count(*) FROM public.%I', t) INTO n;
      IF n > CASE WHEN t = 'notes' THEN 1 ELSE 0 END THEN
        RAISE EXCEPTION 'public.% has % rows, not dropping anything', t, n;
      END IF;
    END IF;
  END LOOP;
END $$;

-- Children before parents.
DROP TABLE IF EXISTS public.habit_entries;
DROP TABLE IF EXISTS public.entity_tags;
DROP TABLE IF EXISTS public.habits;
DROP TABLE IF EXISTS public.tags;
DROP TABLE IF EXISTS public.notes;
DROP TABLE IF EXISTS public.journal_entries;
DROP TABLE IF EXISTS public.attachments;
DROP TABLE IF EXISTS public.sync_queue;
