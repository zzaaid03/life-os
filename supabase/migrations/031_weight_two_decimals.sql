-- 031: weight_kg keeps two decimals.
--
-- With one decimal, 180 lb was stored as 81.6 kg and came back as 179.9 lb.
-- 81.65 kg rounds back to 180 lb. The 20 to 400 CHECK from 030 still applies.
-- Safe to re-run: changing to the same type is a no-op.

ALTER TABLE public.profiles
  ALTER COLUMN weight_kg TYPE NUMERIC(5,2);
