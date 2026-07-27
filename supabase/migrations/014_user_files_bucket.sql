-- Migration 014: the `user-files` Storage bucket and its policies
--
-- SEPARATE FROM MIGRATION 013 ON PURPOSE. Migration 013 secures the metadata
-- TABLE. This one secures the BUCKET. They are different systems with
-- different policy tables, and the classic mistake is to secure the table,
-- see the app working, and leave the bucket readable. Both are required.
--
-- This bucket holds real personal documents (rental contracts, ID scans), and
-- several people share this project, so every policy below is scoped to the
-- owner by the object's first path segment.

-- Private bucket, 10 MB per object. The client also enforces 10 MB before
-- uploading, but a client-side cap is a UX affordance, not a limit, so it is
-- enforced here too. MIME types are left unrestricted: this stores whatever
-- documents people actually have.
INSERT INTO storage.buckets (id, name, public, file_size_limit)
VALUES ('user-files', 'user-files', FALSE, 10485760)
ON CONFLICT (id) DO UPDATE
  SET public = FALSE,
      file_size_limit = 10485760;

-- Every object path is '<user_id>/<uuid><ext>', so the first folder segment
-- IS the owner. storage.foldername(name) splits the path; element 1 is that
-- leading segment. Comparing it to auth.uid() means a user can only ever
-- touch objects under their own prefix, and cannot read another user's file
-- even if they somehow learn its exact path.
--
-- Note this is the only thing standing between two testers' documents: the
-- bucket is private, so there are no public URLs, and reads happen through
-- signed URLs minted only for objects that pass the SELECT policy below.

DROP POLICY IF EXISTS "Users can read own files" ON storage.objects;
CREATE POLICY "Users can read own files"
  ON storage.objects FOR SELECT
  TO authenticated
  USING (
    bucket_id = 'user-files'
    AND (storage.foldername(name))[1] = auth.uid()::text
  );

DROP POLICY IF EXISTS "Users can upload own files" ON storage.objects;
CREATE POLICY "Users can upload own files"
  ON storage.objects FOR INSERT
  TO authenticated
  WITH CHECK (
    bucket_id = 'user-files'
    AND (storage.foldername(name))[1] = auth.uid()::text
  );

DROP POLICY IF EXISTS "Users can update own files" ON storage.objects;
CREATE POLICY "Users can update own files"
  ON storage.objects FOR UPDATE
  TO authenticated
  USING (
    bucket_id = 'user-files'
    AND (storage.foldername(name))[1] = auth.uid()::text
  )
  WITH CHECK (
    bucket_id = 'user-files'
    AND (storage.foldername(name))[1] = auth.uid()::text
  );

DROP POLICY IF EXISTS "Users can delete own files" ON storage.objects;
CREATE POLICY "Users can delete own files"
  ON storage.objects FOR DELETE
  TO authenticated
  USING (
    bucket_id = 'user-files'
    AND (storage.foldername(name))[1] = auth.uid()::text
  );
