-- Create property_location enum type for main areas
CREATE TYPE public.property_location AS ENUM (
  'dovecote',
  'renaissance',
  'oriental',
  'palm_grove',
  'medieval'
);

-- Create property_section enum type for sub-sections (mainly for Renaissance)
CREATE TYPE public.property_section AS ENUM (
  'mezzanine',
  'first_floor',
  'second_floor',
  'attic'
);

-- Add property_location and property_section columns to accommodations table
ALTER TABLE public.accommodations 
ADD COLUMN property_location public.property_location DEFAULT NULL,
ADD COLUMN property_section public.property_section DEFAULT NULL;

-- Add comments for documentation
COMMENT ON COLUMN public.accommodations.property_location IS 'The main area/building of the property where this accommodation is located';
COMMENT ON COLUMN public.accommodations.property_section IS 'The specific section within the main area (e.g., floor level for Renaissance rooms)';

-- Add check constraint to ensure property_section is only used with renaissance location
ALTER TABLE public.accommodations
ADD CONSTRAINT property_section_only_for_renaissance 
CHECK (
  (property_location != 'renaissance' AND property_section IS NULL) OR
  (property_location = 'renaissance') OR
  (property_location IS NULL)
);

-- Create helper functions to get enum values
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

-- Grant execute permissions
GRANT EXECUTE ON FUNCTION public.get_property_location_values() TO authenticated;
GRANT EXECUTE ON FUNCTION public.get_property_location_values() TO anon;
GRANT EXECUTE ON FUNCTION public.get_property_section_values() TO authenticated;
GRANT EXECUTE ON FUNCTION public.get_property_section_values() TO anon;