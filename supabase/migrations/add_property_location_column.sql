-- Simple script to add property_location column to accommodations table
-- Run this in Supabase SQL Editor

-- First check if the type already exists
DO $$ 
BEGIN
    IF NOT EXISTS (SELECT 1 FROM pg_type WHERE typname = 'property_location') THEN
        -- Create property_location enum type
        CREATE TYPE public.property_location AS ENUM (
          'dovecote',
          'renaissance', 
          'oriental',
          'palm_grove',
          'medieval'
        );
    END IF;
END$$;

-- Check if column already exists before adding
DO $$
BEGIN
    IF NOT EXISTS (SELECT 1 FROM information_schema.columns 
                   WHERE table_schema = 'public' 
                   AND table_name = 'accommodations' 
                   AND column_name = 'property_location') THEN
        -- Add property_location column to accommodations table
        ALTER TABLE public.accommodations 
        ADD COLUMN property_location public.property_location DEFAULT NULL;
        
        -- Add comment for documentation  
        COMMENT ON COLUMN public.accommodations.property_location IS 'The location/section of the property where this accommodation is situated';
    END IF;
END$$;

-- Create or replace function to get all enum values (useful for admin interface)
CREATE OR REPLACE FUNCTION public.get_property_location_values()
RETURNS SETOF text
LANGUAGE sql
STABLE
AS $$
  SELECT unnest(enum_range(NULL::property_location))::text;
$$;

-- Grant execute permission on the function
GRANT EXECUTE ON FUNCTION public.get_property_location_values() TO authenticated;
GRANT EXECUTE ON FUNCTION public.get_property_location_values() TO anon;

-- Optional: Set some example values for existing accommodations
-- Uncomment and modify as needed:
-- UPDATE public.accommodations SET property_location = 'renaissance' WHERE title LIKE '%Renaissance%';
-- UPDATE public.accommodations SET property_location = 'medieval' WHERE title LIKE '%Medieval%';
-- UPDATE public.accommodations SET property_location = 'oriental' WHERE title LIKE '%Oriental%';
-- UPDATE public.accommodations SET property_location = 'dovecote' WHERE title LIKE '%Dovecote%';
-- UPDATE public.accommodations SET property_location = 'palm_grove' WHERE title LIKE '%Palm%';