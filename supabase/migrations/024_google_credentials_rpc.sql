-- google_credentials: client access through SECURITY DEFINER functions.
--
-- The browser must not be able to read refresh tokens. Table-level access
-- cannot be narrowed by column because an upsert needs table SELECT, so the
-- three things the app does (save the token, check it exists, delete it) move
-- into functions that use auth.uid() only. This migration does NOT change
-- table grants; 025 does that, once every client uses these functions.

CREATE OR REPLACE FUNCTION public.save_google_refresh_token(
  p_refresh_token text,
  p_scope text DEFAULT NULL
)
RETURNS void
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = ''
AS $$
DECLARE
  v_uid uuid := auth.uid();
BEGIN
  IF v_uid IS NULL THEN
    RAISE EXCEPTION 'not authenticated' USING ERRCODE = '28000';
  END IF;
  IF p_refresh_token IS NULL OR length(p_refresh_token) = 0
     OR length(p_refresh_token) > 4096 THEN
    RAISE EXCEPTION 'invalid refresh token' USING ERRCODE = '22023';
  END IF;
  IF p_scope IS NOT NULL AND length(p_scope) > 2048 THEN
    RAISE EXCEPTION 'invalid scope' USING ERRCODE = '22023';
  END IF;

  INSERT INTO public.google_credentials (user_id, refresh_token, scope)
  VALUES (v_uid, p_refresh_token, p_scope)
  ON CONFLICT (user_id) DO UPDATE
    SET refresh_token = EXCLUDED.refresh_token,
        scope = COALESCE(EXCLUDED.scope, public.google_credentials.scope);
END;
$$;

CREATE OR REPLACE FUNCTION public.google_connected()
RETURNS boolean
LANGUAGE plpgsql
STABLE
SECURITY DEFINER
SET search_path = ''
AS $$
DECLARE
  v_uid uuid := auth.uid();
BEGIN
  IF v_uid IS NULL THEN
    RAISE EXCEPTION 'not authenticated' USING ERRCODE = '28000';
  END IF;
  RETURN EXISTS (
    SELECT 1 FROM public.google_credentials WHERE user_id = v_uid
  );
END;
$$;

CREATE OR REPLACE FUNCTION public.disconnect_google()
RETURNS void
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = ''
AS $$
DECLARE
  v_uid uuid := auth.uid();
BEGIN
  IF v_uid IS NULL THEN
    RAISE EXCEPTION 'not authenticated' USING ERRCODE = '28000';
  END IF;
  DELETE FROM public.google_credentials WHERE user_id = v_uid;
END;
$$;

REVOKE ALL ON FUNCTION public.save_google_refresh_token(text, text) FROM PUBLIC, anon;
REVOKE ALL ON FUNCTION public.google_connected() FROM PUBLIC, anon;
REVOKE ALL ON FUNCTION public.disconnect_google() FROM PUBLIC, anon;

GRANT EXECUTE ON FUNCTION public.save_google_refresh_token(text, text) TO authenticated, service_role;
GRANT EXECUTE ON FUNCTION public.google_connected() TO authenticated, service_role;
GRANT EXECUTE ON FUNCTION public.disconnect_google() TO authenticated, service_role;
