-- Storage Buckets for Castle Booking App
-- Run this in Supabase SQL Editor

-- ============================================
-- CREATE STORAGE BUCKETS
-- ============================================

-- Enable storage extension if not already enabled
CREATE EXTENSION IF NOT EXISTS "storage" SCHEMA "extensions";

-- Create avatars bucket for user profile images
INSERT INTO storage.buckets (id, name, public, avif_autodetection, allowed_mime_types)
VALUES (
    'avatars',
    'avatars',
    true,
    false,
    ARRAY['image/jpeg', 'image/jpg', 'image/png', 'image/webp', 'image/gif', 'image/svg+xml']
) ON CONFLICT (id) DO UPDATE SET
    public = true,
    allowed_mime_types = ARRAY['image/jpeg', 'image/jpg', 'image/png', 'image/webp', 'image/gif', 'image/svg+xml'];

-- Create accommodation-images bucket
INSERT INTO storage.buckets (id, name, public, avif_autodetection, allowed_mime_types)
VALUES (
    'accommodation-images',
    'accommodation-images',
    true,
    false,
    ARRAY['image/jpeg', 'image/jpg', 'image/png', 'image/webp', 'image/gif']
) ON CONFLICT (id) DO UPDATE SET
    public = true,
    allowed_mime_types = ARRAY['image/jpeg', 'image/jpg', 'image/png', 'image/webp', 'image/gif'];

-- Create application-files bucket (for application attachments)
INSERT INTO storage.buckets (id, name, public, avif_autodetection, allowed_mime_types)
VALUES (
    'application-files',
    'application-files',
    false,
    false,
    ARRAY['image/jpeg', 'image/jpg', 'image/png', 'image/webp', 'application/pdf', 'application/msword', 'application/vnd.openxmlformats-officedocument.wordprocessingml.document']
) ON CONFLICT (id) DO UPDATE SET
    public = false,
    allowed_mime_types = ARRAY['image/jpeg', 'image/jpg', 'image/png', 'image/webp', 'application/pdf', 'application/msword', 'application/vnd.openxmlformats-officedocument.wordprocessingml.document'];

-- Create other bucket (for miscellaneous files like favicon)
INSERT INTO storage.buckets (id, name, public, avif_autodetection)
VALUES (
    'other',
    'other',
    true,
    false
) ON CONFLICT (id) DO UPDATE SET
    public = true;

-- ============================================
-- STORAGE POLICIES
-- ============================================

-- Avatars bucket policies
CREATE POLICY "Avatar images are publicly accessible"
ON storage.objects FOR SELECT
USING (bucket_id = 'avatars');

CREATE POLICY "Users can upload their own avatar"
ON storage.objects FOR INSERT
WITH CHECK (
    bucket_id = 'avatars' 
    AND auth.uid()::text = (storage.foldername(name))[1]
);

CREATE POLICY "Users can update their own avatar"
ON storage.objects FOR UPDATE
USING (
    bucket_id = 'avatars' 
    AND auth.uid()::text = (storage.foldername(name))[1]
);

CREATE POLICY "Users can delete their own avatar"
ON storage.objects FOR DELETE
USING (
    bucket_id = 'avatars' 
    AND auth.uid()::text = (storage.foldername(name))[1]
);

-- Accommodation images bucket policies
CREATE POLICY "Accommodation images are publicly accessible"
ON storage.objects FOR SELECT
USING (bucket_id = 'accommodation-images');

CREATE POLICY "Admins can upload accommodation images"
ON storage.objects FOR INSERT
WITH CHECK (
    bucket_id = 'accommodation-images' 
    AND public.is_admin()
);

CREATE POLICY "Admins can update accommodation images"
ON storage.objects FOR UPDATE
USING (
    bucket_id = 'accommodation-images' 
    AND public.is_admin()
);

CREATE POLICY "Admins can delete accommodation images"
ON storage.objects FOR DELETE
USING (
    bucket_id = 'accommodation-images' 
    AND public.is_admin()
);

-- Application files bucket policies
CREATE POLICY "Users can view their own application files"
ON storage.objects FOR SELECT
USING (
    bucket_id = 'application-files' 
    AND (
        auth.uid()::text = (storage.foldername(name))[1]
        OR public.is_admin()
    )
);

CREATE POLICY "Users can upload their own application files"
ON storage.objects FOR INSERT
WITH CHECK (
    bucket_id = 'application-files' 
    AND auth.uid()::text = (storage.foldername(name))[1]
);

CREATE POLICY "Users can update their own application files"
ON storage.objects FOR UPDATE
USING (
    bucket_id = 'application-files' 
    AND auth.uid()::text = (storage.foldername(name))[1]
);

CREATE POLICY "Users can delete their own application files"
ON storage.objects FOR DELETE
USING (
    bucket_id = 'application-files' 
    AND (
        auth.uid()::text = (storage.foldername(name))[1]
        OR public.is_admin()
    )
);

-- Other bucket policies (public read for all)
CREATE POLICY "Other files are publicly accessible"
ON storage.objects FOR SELECT
USING (bucket_id = 'other');

CREATE POLICY "Admins can manage other files"
ON storage.objects FOR ALL
USING (
    bucket_id = 'other' 
    AND public.is_admin()
);

-- ============================================
-- DONE! Storage buckets created.
-- ============================================