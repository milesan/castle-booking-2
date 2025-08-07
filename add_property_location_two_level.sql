-- Two-level property location system
-- Run this in Supabase SQL Editor

-- Drop old column if it exists (from previous attempt)
DO $$
BEGIN
    IF EXISTS (SELECT 1 FROM information_schema.columns 
               WHERE table_schema = 'public' 
               AND table_name = 'accommodations' 
               AND column_name = 'property_location') THEN
        ALTER TABLE public.accommodations DROP COLUMN property_location;
    END IF;
END$$;

-- Drop old type if it exists
DROP TYPE IF EXISTS public.property_location CASCADE;

-- Create property_location enum type for main areas
CREATE TYPE public.property_location AS ENUM (
  'dovecote',
  'renaissance',
  'oriental',
  'palm_grove',
  'medieval'
);

-- Create property_section enum type for sub-sections
DO $$ 
BEGIN
    IF NOT EXISTS (SELECT 1 FROM pg_type WHERE typname = 'property_section') THEN
        CREATE TYPE public.property_section AS ENUM (
          'mezzanine',
          'first_floor',
          'second_floor',
          'attic'
        );
    END IF;
END$$;

-- Add columns if they don't exist
DO $$
BEGIN
    IF NOT EXISTS (SELECT 1 FROM information_schema.columns 
                   WHERE table_schema = 'public' 
                   AND table_name = 'accommodations' 
                   AND column_name = 'property_location') THEN
        ALTER TABLE public.accommodations 
        ADD COLUMN property_location public.property_location DEFAULT NULL;
    END IF;
    
    IF NOT EXISTS (SELECT 1 FROM information_schema.columns 
                   WHERE table_schema = 'public' 
                   AND table_name = 'accommodations' 
                   AND column_name = 'property_section') THEN
        ALTER TABLE public.accommodations 
        ADD COLUMN property_section public.property_section DEFAULT NULL;
    END IF;
END$$;

-- Add comments
COMMENT ON COLUMN public.accommodations.property_location IS 'The main area/building of the property where this accommodation is located';
COMMENT ON COLUMN public.accommodations.property_section IS 'The specific section within the main area (e.g., floor level for Renaissance rooms)';

-- Add check constraint (drop first if exists)
ALTER TABLE public.accommodations
DROP CONSTRAINT IF EXISTS property_section_only_for_renaissance;

ALTER TABLE public.accommodations
ADD CONSTRAINT property_section_only_for_renaissance 
CHECK (
  (property_location != 'renaissance' AND property_section IS NULL) OR
  (property_location = 'renaissance') OR
  (property_location IS NULL)
);

-- Create helper functions
CREATE OR REPLACE FUNCTION public.get_property_location_values()
RETURNS SETOF text
LANGUAGE sql
STABLE
AS $$
  SELECT unnest(enum_range(NULL::property_location))::text;
$$;

CREATE OR REPLACE FUNCTION public.get_property_section_values()
RETURNS SETOF text
LANGUAGE sql
STABLE
AS $$
  SELECT unnest(enum_range(NULL::property_section))::text;
$$;

-- Grant permissions
GRANT EXECUTE ON FUNCTION public.get_property_location_values() TO authenticated;
GRANT EXECUTE ON FUNCTION public.get_property_location_values() TO anon;
GRANT EXECUTE ON FUNCTION public.get_property_section_values() TO authenticated;
GRANT EXECUTE ON FUNCTION public.get_property_section_values() TO anon;