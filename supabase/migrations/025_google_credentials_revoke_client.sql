-- google_credentials: take direct table access away from the client.
--
-- APPLY ONLY AFTER EVERY CLIENT USES THE RPCs FROM 024: the new web deploy
-- AND the new iOS build installed on the phone. An older client still calls
-- the table directly and will get 42501 (Gmail connect and Settings break).
--
-- After this, only the SECURITY DEFINER functions from 024 and service_role
-- (the extract-tasks edge function) can touch refresh tokens.

REVOKE ALL ON public.google_credentials FROM authenticated, anon;
GRANT SELECT, INSERT, UPDATE, DELETE ON public.google_credentials TO service_role;
