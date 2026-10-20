-- google_credentials: drop anon access.
--
-- This migration first tried to hide refresh_token from the app by granting
-- authenticated SELECT on the other columns only. That broke Gmail connect:
-- the app saves the token with an upsert (INSERT ... ON CONFLICT DO UPDATE),
-- and Postgres needs SELECT on the table for that, so every save returned
-- 42501. It was rolled back the same day by restoring the table-level SELECT.
--
-- Hiding the token properly needs the save to move behind a SECURITY DEFINER
-- function first, and every installed app build to use it, before SELECT can
-- be revoked. Until then the app keeps the access it always had.

REVOKE ALL ON public.google_credentials FROM anon;
GRANT SELECT ON public.google_credentials TO authenticated;
