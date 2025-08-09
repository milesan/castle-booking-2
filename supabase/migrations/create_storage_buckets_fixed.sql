-- Storage Buckets for Castle Booking App (Fixed for Supabase)
-- Run this in Supabase SQL Editor
-- Note: You may also need to create these buckets via the Supabase Dashboard

-- ============================================
-- CREATE STORAGE BUCKETS
-- ============================================

-- Supabase already has the storage schema, we just need to create buckets
-- If these fail, create the buckets manually in the Dashboard under Storage

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
-- STORAGE POLICIES (RLS)
-- ============================================

-- First, clean up any existing policies to avoid conflicts
DO $$ 
BEGIN
    -- Drop existing policies if they exist
    DROP POLICY IF EXISTS "Avatar images are publicly accessible" ON storage.objects;
    DROP POLICY IF EXISTS "Users can upload their own avatar" ON storage.objects;
    DROP POLICY IF EXISTS "Users can update their own avatar" ON storage.objects;
    DROP POLICY IF EXISTS "Users can delete their own avatar" ON storage.objects;
    
    DROP POLICY IF EXISTS "Accommodation images are publicly accessible" ON storage.objects;
    DROP POLICY IF EXISTS "Admins can upload accommodation images" ON storage.objects;
    DROP POLICY IF EXISTS "Admins can update accommodation images" ON storage.objects;
    DROP POLICY IF EXISTS "Admins can delete accommodation images" ON storage.objects;
    
    DROP POLICY IF EXISTS "Users can view their own application files" ON storage.objects;
    DROP POLICY IF EXISTS "Users can upload their own application files" ON storage.objects;
    DROP POLICY IF EXISTS "Users can update their own application files" ON storage.objects;
    DROP POLICY IF EXISTS "Users can delete their own application files" ON storage.objects;
    
    DROP POLICY IF EXISTS "Other files are publicly accessible" ON storage.objects;
    DROP POLICY IF EXISTS "Admins can manage other files" ON storage.objects;
EXCEPTION
    WHEN OTHERS THEN NULL;
END $$;

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
    AND EXISTS (
        SELECT 1 FROM public.profiles
        WHERE id = auth.uid()
        AND is_admin = true
    )
);

CREATE POLICY "Admins can update accommodation images"
ON storage.objects FOR UPDATE
USING (
    bucket_id = 'accommodation-images' 
    AND EXISTS (
        SELECT 1 FROM public.profiles
        WHERE id = auth.uid()
        AND is_admin = true
    )
);

CREATE POLICY "Admins can delete accommodation images"
ON storage.objects FOR DELETE
USING (
    bucket_id = 'accommodation-images' 
    AND EXISTS (
        SELECT 1 FROM public.profiles
        WHERE id = auth.uid()
        AND is_admin = true
    )
);

-- Application files bucket policies
CREATE POLICY "Users can view their own application files"
ON storage.objects FOR SELECT
USING (
    bucket_id = 'application-files' 
    AND (
        auth.uid()::text = (storage.foldername(name))[1]
        OR EXISTS (
            SELECT 1 FROM public.profiles
            WHERE id = auth.uid()
            AND is_admin = true
        )
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
        OR EXISTS (
            SELECT 1 FROM public.profiles
            WHERE id = auth.uid()
            AND is_admin = true
        )
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
    AND EXISTS (
        SELECT 1 FROM public.profiles
        WHERE id = auth.uid()
        AND is_admin = true
    )
);

-- ============================================
-- ALTERNATIVE: Manual Creation
-- ============================================
-- If the above SQL doesn't work, create buckets manually:
-- 1. Go to Storage in Supabase Dashboard
-- 2. Click "New bucket"
-- 3. Create these buckets:
--    - avatars (public)
--    - accommodation-images (public)
--    - application-files (private)
--    - other (public)
-- ============================================