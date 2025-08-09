-- Create accommodation_images table to track uploaded images

-- 1. Create the accommodation_images table
CREATE TABLE IF NOT EXISTS public.accommodation_images (
    id uuid DEFAULT gen_random_uuid() PRIMARY KEY,
    accommodation_id uuid NOT NULL REFERENCES public.accommodations(id) ON DELETE CASCADE,
    url text NOT NULL,
    display_order integer DEFAULT 0,
    caption text,
    created_at timestamp with time zone DEFAULT timezone('utc'::text, now()) NOT NULL,
    updated_at timestamp with time zone DEFAULT timezone('utc'::text, now()) NOT NULL
);

-- 2. Create indexes for better performance
CREATE INDEX IF NOT EXISTS idx_accommodation_images_accommodation_id 
    ON public.accommodation_images(accommodation_id);

CREATE INDEX IF NOT EXISTS idx_accommodation_images_display_order 
    ON public.accommodation_images(display_order);

-- 3. Enable RLS
ALTER TABLE public.accommodation_images ENABLE ROW LEVEL SECURITY;

-- 4. Create RLS policies
-- Allow anyone to view accommodation images
CREATE POLICY "Anyone can view accommodation images"
    ON public.accommodation_images
    FOR SELECT
    USING (true);

-- Allow admins to insert accommodation images
CREATE POLICY "Admins can insert accommodation images"
    ON public.accommodation_images
    FOR INSERT
    WITH CHECK (public.is_admin());

-- Allow admins to update accommodation images
CREATE POLICY "Admins can update accommodation images"
    ON public.accommodation_images
    FOR UPDATE
    USING (public.is_admin())
    WITH CHECK (public.is_admin());

-- Allow admins to delete accommodation images
CREATE POLICY "Admins can delete accommodation images"
    ON public.accommodation_images
    FOR DELETE
    USING (public.is_admin());

-- 5. Create a trigger to update the updated_at column
CREATE OR REPLACE FUNCTION public.update_updated_at_column()
RETURNS TRIGGER AS $$
BEGIN
    NEW.updated_at = timezone('utc'::text, now());
    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

-- Drop trigger if exists and recreate
DROP TRIGGER IF EXISTS update_accommodation_images_updated_at ON public.accommodation_images;

CREATE TRIGGER update_accommodation_images_updated_at
    BEFORE UPDATE ON public.accommodation_images
    FOR EACH ROW
    EXECUTE FUNCTION public.update_updated_at_column();

-- 6. Grant necessary permissions
GRANT SELECT ON public.accommodation_images TO anon;
GRANT SELECT, INSERT, UPDATE, DELETE ON public.accommodation_images TO authenticated;

-- 7. Verify the table was created
SELECT 
    column_name,
    data_type,
    is_nullable,
    column_default
FROM information_schema.columns
WHERE table_schema = 'public' 
AND table_name = 'accommodation_images'
ORDER BY ordinal_position;

-- 8. Check RLS policies
SELECT 
    policyname,
    cmd,
    qual,
    with_check
FROM pg_policies
WHERE tablename = 'accommodation_images';