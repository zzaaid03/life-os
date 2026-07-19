-- Migration 005: Improve display name resolution
--
-- Migration 001's handle_new_user() trigger only checked the
-- `display_name` metadata key before falling back to the email
-- prefix. Email/password sign-up populates `display_name`, but
-- Google (and most OAuth providers) instead populate `full_name`
-- or `name` -- so every Google sign-in ended up with the email
-- prefix as their display name instead of their real name.
--
-- This migration:
--   1. Replaces handle_new_user() so new sign-ups check
--      display_name, then full_name, then name, before falling
--      back to the email prefix.
--   2. Backfills existing profiles whose display_name still
--      matches the email prefix (i.e. it was never a real name),
--      pulling the real name from auth.users.raw_user_meta_data
--      where one is now available.
--
-- This migration MUST be run after 001_create_profiles.sql.
--
-- Safe to re-run: the function uses CREATE OR REPLACE, and the
-- backfill UPDATE only touches rows that still look like the old
-- email-prefix fallback, so re-running it is a no-op once applied.

-- Function: Automatically create profile on user sign-up.
-- Reproduces 001_create_profiles.sql's handle_new_user() exactly,
-- extending only the display_name COALESCE chain.
CREATE OR REPLACE FUNCTION public.handle_new_user()
RETURNS TRIGGER
LANGUAGE plpgsql
SECURITY DEFINER SET search_path = ''
AS $$
BEGIN
  INSERT INTO public.profiles (
    id,
    display_name,
    email,
    avatar_url,
    provider
  ) VALUES (
    NEW.id,
    COALESCE(
      NEW.raw_user_meta_data ->> 'display_name',
      NEW.raw_user_meta_data ->> 'full_name',
      NEW.raw_user_meta_data ->> 'name',
      split_part(NEW.email, '@', 1)
    ),
    NEW.email,
    NEW.raw_user_meta_data ->> 'avatar_url',
    COALESCE(NEW.raw_app_meta_data ->> 'provider', 'email')
  );
  RETURN NEW;
END;
$$;

-- Backfill: update existing profiles whose display_name is still
-- just the email prefix (the old fallback value), using the real
-- name from auth.users metadata where one is now available.
UPDATE public.profiles p
SET
  display_name = COALESCE(
    u.raw_user_meta_data ->> 'display_name',
    u.raw_user_meta_data ->> 'full_name',
    u.raw_user_meta_data ->> 'name'
  ),
  updated_at = NOW()
FROM auth.users u
WHERE p.id = u.id
  AND p.display_name = split_part(p.email, '@', 1)
  AND COALESCE(
    u.raw_user_meta_data ->> 'display_name',
    u.raw_user_meta_data ->> 'full_name',
    u.raw_user_meta_data ->> 'name'
  ) IS NOT NULL;
