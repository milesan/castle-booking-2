-- Fix accommodation descriptions: syntax, formatting, and bathroom information
-- This migration updates all accommodation descriptions for clarity and consistency

BEGIN;

-- Update accommodations with proper descriptions and bathroom information
UPDATE public.accommodations
SET 
  additional_info = CASE
    -- The Dovecote - Fix capitalization and formatting
    WHEN title = 'The Dovecote' THEN 
      'Bed 0210 at first floor • Bath on ground floor • Bluetooth amplifier'
    
    -- Rooms with private bathrooms (en-suite)
    WHEN title = 'The Hearth' THEN 
      'King bed • Private bathroom • Fireplace • Premium suite'
    
    WHEN title = 'Writer''s Room' THEN 
      'Queen bed • Private bathroom • Writing desk • Mountain views'
    
    WHEN title = 'Valleyview Room' THEN 
      'Queen bed • Private bathroom • Valley views • Balcony'
    
    -- Cabins and glamping with shared bathrooms
    WHEN title LIKE 'Microcabin%' THEN 
      'Double bed • Shared bathroom facilities • Electricity • Compact design'
    
    WHEN title = 'The Yurt' THEN 
      'King bed • Shared bathroom facilities • Wood stove • Traditional Mongolian design'
    
    WHEN title = 'A-Frame Pod' THEN 
      'Double bed • Shared bathroom facilities • Unique architecture • Forest views'
    
    -- Bell tents and tipis with shared facilities
    WHEN title = '4 Meter Bell Tent' THEN 
      'Double mattress • Shared bathroom facilities • Canvas glamping'
    
    WHEN title = '5m Bell Tent' THEN 
      'Double mattress • Shared bathroom facilities • Spacious canvas glamping'
    
    WHEN title = '2.2 Meter Tipi' THEN 
      'Single mattress • Shared bathroom facilities • Traditional tipi'
    
    WHEN title = 'Single Tipi' THEN 
      'Single mattress • Shared bathroom facilities • Cozy traditional tipi'
    
    -- Dorms with shared bathrooms
    WHEN title = '3-Bed Dorm' THEN 
      'Single bed in shared room • Shared bathroom • Lockers • Social atmosphere'
    
    WHEN title = '6-Bed Dorm' THEN 
      'Single bed in shared room • Shared bathroom • Lockers • Budget-friendly'
    
    WHEN title = 'Wedding Hall Dorm' THEN 
      'Single bed in wedding hall • Shared bathroom • Historic setting • Community space'
    
    WHEN title = 'Shared Dorm' THEN 
      'Single bed in shared room • Shared bathroom • Budget option'
    
    -- Camping and parking
    WHEN title = 'Your Own Tent' THEN 
      'BYO tent • Shared bathroom facilities • Choose your spot'
    
    WHEN title = 'Van Parking' THEN 
      'Van/RV parking spot • Shared bathroom facilities • Power hookup available'
    
    WHEN title = 'Staying with somebody' THEN 
      'Arrangements vary • Contact host for details'
    
    -- Keep existing if not listed
    ELSE additional_info
  END,
  
  -- Add a new column to track bathroom type (we'll add this column first)
  updated_at = NOW()
WHERE title IS NOT NULL;

-- Add bathroom_type column if it doesn't exist
DO $$
BEGIN
  IF NOT EXISTS (
    SELECT 1 FROM information_schema.columns 
    WHERE table_schema = 'public' 
    AND table_name = 'accommodations' 
    AND column_name = 'bathroom_type'
  ) THEN
    ALTER TABLE public.accommodations 
    ADD COLUMN bathroom_type text CHECK (bathroom_type IN ('private', 'shared', 'none'));
    
    COMMENT ON COLUMN public.accommodations.bathroom_type IS 'Type of bathroom access: private (en-suite), shared (communal facilities), or none';
  END IF;
END $$;

-- Now update bathroom_type based on accommodation details
UPDATE public.accommodations
SET bathroom_type = CASE
  -- Rooms with private bathrooms
  WHEN title IN ('The Hearth', 'Writer''s Room', 'Valleyview Room', 'The Dovecote') THEN 'private'
  
  -- Everything else has shared bathrooms
  WHEN title IN (
    'Microcabin', 'Microcabin Left', 'Microcabin Right', 'Microcabin Middle',
    'The Yurt', 'A-Frame Pod',
    '4 Meter Bell Tent', '5m Bell Tent', 
    '2.2 Meter Tipi', 'Single Tipi',
    '3-Bed Dorm', '6-Bed Dorm', 'Wedding Hall Dorm', 'Shared Dorm',
    'Your Own Tent', 'Van Parking'
  ) THEN 'shared'
  
  -- Special case
  WHEN title = 'Staying with somebody' THEN 'none' -- Varies by arrangement
  
  ELSE bathroom_type -- Keep existing if set
END
WHERE title IS NOT NULL;

-- Add indexes for better query performance
CREATE INDEX IF NOT EXISTS idx_accommodations_bathroom_type 
ON public.accommodations(bathroom_type) 
WHERE bathroom_type IS NOT NULL;

CREATE INDEX IF NOT EXISTS idx_accommodations_property_location 
ON public.accommodations(property_location) 
WHERE property_location IS NOT NULL;

-- Log the changes
DO $$
DECLARE
  private_count INTEGER;
  shared_count INTEGER;
  none_count INTEGER;
BEGIN
  SELECT COUNT(*) INTO private_count FROM public.accommodations WHERE bathroom_type = 'private';
  SELECT COUNT(*) INTO shared_count FROM public.accommodations WHERE bathroom_type = 'shared';
  SELECT COUNT(*) INTO none_count FROM public.accommodations WHERE bathroom_type = 'none';
  
  RAISE NOTICE 'Updated accommodation descriptions and bathroom types:';
  RAISE NOTICE '  - Private bathrooms: %', private_count;
  RAISE NOTICE '  - Shared bathrooms: %', shared_count;
  RAISE NOTICE '  - No bathroom info: %', none_count;
END $$;

COMMIT;