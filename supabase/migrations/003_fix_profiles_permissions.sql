-- Migration 003: Fix profiles table permissions
--
-- Migration 001 created the profiles table with correct RLS policies,
-- but table-level privileges were never granted to the PostgREST
-- roles (authenticated, anon). Without these grants, every query
-- returns "permission denied (42501)" regardless of RLS policies.
--
-- This migration MUST be run after 001_create_profiles.sql.
--
-- No existing data is affected. All operations are additive and
-- idempotent (safe to re-run).

-- Grant schema usage to both roles
GRANT USAGE ON SCHEMA public TO anon, authenticated;

-- Grant table-level privileges to the authenticated role.
-- PostgREST connects as 'authenticated' for JWT-authenticated
-- requests. Without these grants, every query returns 42501.
GRANT SELECT, INSERT, UPDATE, DELETE ON public.profiles TO authenticated;

-- Grant SELECT to anon. Needed because the handle_new_user() trigger
-- function (SECURITY DEFINER) may interact with the table in contexts
-- where the session role has not yet been fully established.
GRANT SELECT ON public.profiles TO anon;

-- Grant execute on the trigger function so it can run regardless
-- of who initiates the sign-up.
GRANT EXECUTE ON FUNCTION public.handle_new_user()
  TO anon, authenticated, supabase_auth_admin;

-- Add DELETE policy (was missing in migration 001).
DROP POLICY IF EXISTS "Users can delete own profile" ON public.profiles;
CREATE POLICY "Users can delete own profile"
  ON public.profiles
  FOR DELETE
  USING (auth.uid() = id);
