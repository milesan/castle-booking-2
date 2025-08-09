-- Create storage bucket for accommodation photos

-- 1. Create the accommodations bucket if it doesn't exist
INSERT INTO storage.buckets (id, name, public, avif_autodetection, file_size_limit, allowed_mime_types)
VALUES (
    'accommodations',
    'accommodations', 
    true, -- public bucket so images can be viewed without authentication
    false,
    5242880, -- 5MB file size limit
    ARRAY['image/jpeg', 'image/jpg', 'image/png', 'image/webp', 'image/gif', 'image/svg+xml']
)
ON CONFLICT (id) DO UPDATE
SET 
    public = true,
    file_size_limit = 5242880,
    allowed_mime_types = ARRAY['image/jpeg', 'image/jpg', 'image/png', 'image/webp', 'image/gif', 'image/svg+xml'];

-- 2. Set up RLS policies for the bucket
-- Allow anyone to view accommodation images
CREATE POLICY "Public can view accommodation images"
    ON storage.objects
    FOR SELECT
    USING (bucket_id = 'accommodations');

-- Allow authenticated users to upload images
CREATE POLICY "Authenticated users can upload accommodation images"
    ON storage.objects
    FOR INSERT
    WITH CHECK (
        bucket_id = 'accommodations' 
        AND auth.role() = 'authenticated'
    );

-- Allow admins to update/delete images
CREATE POLICY "Admins can manage accommodation images"
    ON storage.objects
    FOR ALL
    USING (
        bucket_id = 'accommodations' 
        AND public.is_admin()
    );

-- 3. Verify the bucket was created
SELECT 
    id,
    name,
    public,
    file_size_limit,
    allowed_mime_types
FROM storage.buckets
WHERE id = 'accommodations';

-- 4. Check existing storage buckets
SELECT 
    id,
    name,
    public,
    created_at
FROM storage.buckets
ORDER BY created_at;