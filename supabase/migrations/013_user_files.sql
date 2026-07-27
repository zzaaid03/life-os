-- Migration 013: file storage metadata
--
-- One row per uploaded file. The bytes live in the `user-files` Storage
-- bucket at storage_path; this table is only the metadata. The bucket and
-- its own policies are migration 014 — securing this table does NOT secure
-- the bucket, they are two separate systems.
--
-- Files are network-only by design: there is no Drift mirror and no offline
-- sync, the same deliberate choice already made for goals.

CREATE TABLE IF NOT EXISTS public.user_files (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id UUID NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,

  -- Path of the object inside the `user-files` bucket. Always
  -- '<user_id>/<uuid><ext>'. The leading user-id folder is what the bucket
  -- policies in 014 match on, so it is load-bearing, not cosmetic.
  storage_path TEXT NOT NULL UNIQUE,

  file_name TEXT NOT NULL,
  mime_type TEXT NOT NULL DEFAULT 'application/octet-stream',
  size_bytes BIGINT NOT NULL DEFAULT 0,

  -- "Private, never send to AI". When true the file is excluded from AI
  -- labelling and from anything that would transmit it to a third party.
  is_private BOOLEAN NOT NULL DEFAULT FALSE,

  -- AI-generated label. Stays NULL until the labelling slice, and is never
  -- set for a row where is_private is true.
  ai_label TEXT,

  -- Optional attachment to another entity. Kept as a loose type+id pair
  -- rather than two nullable FKs so a third attachable type does not need a
  -- schema change.
  attached_entity_type TEXT
    CHECK (attached_entity_type IN ('task', 'job_application')),
  attached_entity_id UUID,

  created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),

  -- Soft delete, consistent with tasks and goals. Note the app also removes
  -- the storage object for real, because storage quota is shared across every
  -- tester and a soft delete alone would leak space permanently.
  deleted_at TIMESTAMPTZ,

  -- An attachment must name both a type and an id, or neither.
  CONSTRAINT user_files_attachment_complete CHECK (
    (attached_entity_type IS NULL AND attached_entity_id IS NULL)
    OR (attached_entity_type IS NOT NULL AND attached_entity_id IS NOT NULL)
  )
);

-- The list query: a user's live files, newest first.
CREATE INDEX IF NOT EXISTS user_files_user_created_idx
  ON public.user_files (user_id, created_at DESC)
  WHERE deleted_at IS NULL;

-- Looking up what is attached to a given task or job application.
CREATE INDEX IF NOT EXISTS user_files_attachment_idx
  ON public.user_files (attached_entity_type, attached_entity_id)
  WHERE deleted_at IS NULL;

ALTER TABLE public.user_files ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS "Users can view own files" ON public.user_files;
CREATE POLICY "Users can view own files"
  ON public.user_files FOR SELECT
  USING (auth.uid() = user_id);

DROP POLICY IF EXISTS "Users can insert own files" ON public.user_files;
CREATE POLICY "Users can insert own files"
  ON public.user_files FOR INSERT
  WITH CHECK (auth.uid() = user_id);

DROP POLICY IF EXISTS "Users can update own files" ON public.user_files;
CREATE POLICY "Users can update own files"
  ON public.user_files FOR UPDATE
  USING (auth.uid() = user_id)
  WITH CHECK (auth.uid() = user_id);

DROP POLICY IF EXISTS "Users can delete own files" ON public.user_files;
CREATE POLICY "Users can delete own files"
  ON public.user_files FOR DELETE
  USING (auth.uid() = user_id);

-- RLS is not a table grant. Without these the roles get a bare 42501
-- permission denied regardless of the policies above. This has bitten this
-- project three times; service_role is included so an Edge Function can read
-- these rows for AI labelling later.
GRANT SELECT, INSERT, UPDATE, DELETE ON public.user_files
  TO authenticated, service_role;

-- Keep updated_at fresh on every update.
CREATE OR REPLACE FUNCTION public.touch_user_files_updated_at()
RETURNS TRIGGER
LANGUAGE plpgsql
SECURITY DEFINER SET search_path = ''
AS $$
BEGIN
  NEW.updated_at = NOW();
  RETURN NEW;
END;
$$;

DROP TRIGGER IF EXISTS on_user_files_updated ON public.user_files;
CREATE TRIGGER on_user_files_updated
  BEFORE UPDATE ON public.user_files
  FOR EACH ROW
  EXECUTE FUNCTION public.touch_user_files_updated_at();
