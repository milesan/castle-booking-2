-- Fix accommodation_images table to match frontend expectations

-- 1. Rename url column to image_url if needed
DO $$
BEGIN
    -- Check if url column exists and image_url doesn't
    IF EXISTS (
        SELECT 1 FROM information_schema.columns 
        WHERE table_schema = 'public' 
        AND table_name = 'accommodation_images' 
        AND column_name = 'url'
    ) AND NOT EXISTS (
        SELECT 1 FROM information_schema.columns 
        WHERE table_schema = 'public' 
        AND table_name = 'accommodation_images' 
        AND column_name = 'image_url'
    ) THEN
        ALTER TABLE public.accommodation_images 
        RENAME COLUMN url TO image_url;
        RAISE NOTICE 'Renamed url column to image_url';
    END IF;
    
    -- If image_url doesn't exist at all, add it
    IF NOT EXISTS (
        SELECT 1 FROM information_schema.columns 
        WHERE table_schema = 'public' 
        AND table_name = 'accommodation_images' 
        AND column_name = 'image_url'
    ) THEN
        ALTER TABLE public.accommodation_images 
        ADD COLUMN image_url text NOT NULL;
        RAISE NOTICE 'Added image_url column';
    END IF;
END $$;

-- 2. Add is_primary column if it doesn't exist
DO $$
BEGIN
    IF NOT EXISTS (
        SELECT 1 FROM information_schema.columns 
        WHERE table_schema = 'public' 
        AND table_name = 'accommodation_images' 
        AND column_name = 'is_primary'
    ) THEN
        ALTER TABLE public.accommodation_images 
        ADD COLUMN is_primary boolean DEFAULT false;
        RAISE NOTICE 'Added is_primary column';
    END IF;
END $$;

-- 3. Verify the table structure
SELECT 
    column_name,
    data_type,
    is_nullable,
    column_default
FROM information_schema.columns
WHERE table_schema = 'public' 
AND table_name = 'accommodation_images'
ORDER BY ordinal_position;

-- 4. Ensure only one primary image per accommodation (constraint)
DO $$
BEGIN
    -- Drop existing constraint if it exists
    IF EXISTS (
        SELECT 1 FROM pg_constraint 
        WHERE conname = 'one_primary_per_accommodation'
    ) THEN
        ALTER TABLE public.accommodation_images
        DROP CONSTRAINT one_primary_per_accommodation;
    END IF;
END $$;

-- Create unique index for primary images
CREATE UNIQUE INDEX IF NOT EXISTS idx_one_primary_per_accommodation
ON public.accommodation_images (accommodation_id)
WHERE is_primary = true;

-- 5. Show final state
SELECT 
    'accommodation_images table ready' as status,
    COUNT(*) as column_count
FROM information_schema.columns
WHERE table_schema = 'public' 
AND table_name = 'accommodation_images';