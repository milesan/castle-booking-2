-- Simple script to rename bed_size to additional_info
-- Run this in Supabase SQL Editor

-- Check if bed_size column exists and additional_info doesn't exist
DO $$
BEGIN
    IF EXISTS (SELECT 1 FROM information_schema.columns 
               WHERE table_schema = 'public' 
               AND table_name = 'accommodations' 
               AND column_name = 'bed_size') 
       AND NOT EXISTS (SELECT 1 FROM information_schema.columns 
                       WHERE table_schema = 'public' 
                       AND table_name = 'accommodations' 
                       AND column_name = 'additional_info') THEN
        -- Rename the column
        ALTER TABLE public.accommodations 
        RENAME COLUMN bed_size TO additional_info;
        
        -- Update the comment
        COMMENT ON COLUMN public.accommodations.additional_info IS 'Additional information about the accommodation (e.g., bed details, bathroom location, amenities)';
    END IF;
END$$;