-- Create storage bucket for bug report attachments
INSERT INTO storage.buckets (id, name, public, file_size_limit, allowed_mime_types)
VALUES (
  'bug-report-attachments',
  'bug-report-attachments',
  true, -- Public bucket so images can be viewed
  5242880, -- 5MB limit per file
  ARRAY['image/jpeg', 'image/jpg', 'image/png', 'image/gif', 'image/webp']
)
ON CONFLICT (id) DO UPDATE SET
  public = EXCLUDED.public,
  file_size_limit = EXCLUDED.file_size_limit,
  allowed_mime_types = EXCLUDED.allowed_mime_types;

-- Storage policies for bug report attachments

-- Policy: Authenticated users can upload files
CREATE POLICY "Authenticated users can upload bug report attachments"
ON storage.objects
FOR INSERT
TO authenticated
WITH CHECK (
  bucket_id = 'bug-report-attachments' 
  AND (storage.foldername(name))[1] = 'public'
);

-- Policy: Anyone can view bug report attachments (public bucket)
CREATE POLICY "Anyone can view bug report attachments"
ON storage.objects
FOR SELECT
TO public
USING (bucket_id = 'bug-report-attachments');

-- Policy: Users can delete their own uploaded attachments
CREATE POLICY "Users can delete own bug report attachments"
ON storage.objects
FOR DELETE
TO authenticated
USING (
  bucket_id = 'bug-report-attachments'
  AND auth.uid()::text = (storage.foldername(name))[2]
);

-- Policy: Admins can delete any bug report attachments
CREATE POLICY "Admins can delete any bug report attachments"
ON storage.objects
FOR DELETE
TO authenticated
USING (
  bucket_id = 'bug-report-attachments'
  AND EXISTS (
    SELECT 1 FROM profiles
    WHERE profiles.id = auth.uid()
    AND profiles.is_admin = true
  )
);

COMMENT ON POLICY "Authenticated users can upload bug report attachments" ON storage.objects IS 'Allows authenticated users to upload screenshots for bug reports';
COMMENT ON POLICY "Anyone can view bug report attachments" ON storage.objects IS 'Makes bug report screenshots publicly viewable';
COMMENT ON POLICY "Users can delete own bug report attachments" ON storage.objects IS 'Allows users to delete their own uploaded screenshots';
COMMENT ON POLICY "Admins can delete any bug report attachments" ON storage.objects IS 'Allows admins to manage all bug report attachments';