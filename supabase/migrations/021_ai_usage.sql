-- Daily AI call counter per user, so one account cannot run up the model bill.
-- Edge functions call consume_ai_call before every model request. Only the
-- service role can read, write or call anything here; the app never touches it.

CREATE TABLE IF NOT EXISTS public.ai_usage (
  user_id uuid NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
  day date NOT NULL,
  calls integer NOT NULL DEFAULT 0,
  PRIMARY KEY (user_id, day)
);

ALTER TABLE public.ai_usage ENABLE ROW LEVEL SECURITY;

REVOKE ALL ON public.ai_usage FROM anon, authenticated;
GRANT SELECT, INSERT, UPDATE ON public.ai_usage TO service_role;

-- Counts one call for today (UTC) and returns true while the user is still
-- within p_limit. The upsert is atomic, so parallel requests cannot slip past.
CREATE OR REPLACE FUNCTION public.consume_ai_call(p_user_id uuid, p_limit integer)
RETURNS boolean
LANGUAGE plpgsql
SECURITY INVOKER
SET search_path = ''
AS $$
DECLARE
  v_calls integer;
BEGIN
  INSERT INTO public.ai_usage AS u (user_id, day, calls)
  VALUES (p_user_id, (now() AT TIME ZONE 'utc')::date, 1)
  ON CONFLICT (user_id, day) DO UPDATE SET calls = u.calls + 1
  RETURNING u.calls INTO v_calls;

  RETURN v_calls <= p_limit;
END;
$$;

REVOKE EXECUTE ON FUNCTION public.consume_ai_call(uuid, integer) FROM public, anon, authenticated;
GRANT EXECUTE ON FUNCTION public.consume_ai_call(uuid, integer) TO service_role;
