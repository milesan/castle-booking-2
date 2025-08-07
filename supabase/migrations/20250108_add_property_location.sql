-- Create property_location enum type
CREATE TYPE public.property_location AS ENUM (
  'dovecote',
  'renaissance',
  'oriental',
  'palm_grove',
  'medieval'
);

-- Add property_location column to accommodations table
ALTER TABLE public.accommodations 
ADD COLUMN property_location public.property_location DEFAULT NULL;

-- Add comment for documentation
COMMENT ON COLUMN public.accommodations.property_location IS 'The location/section of the property where this accommodation is situated';

-- Create function to get all enum values (useful for admin interface)
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