-- Comprehensive fix for all accommodation descriptions and bathroom detection
-- This migration:
-- 1. Fixes syntax and grammar in all descriptions
-- 2. Intelligently detects bathroom type from descriptions
-- 3. Ensures consistent formatting

BEGIN;

-- First, update all descriptions with proper grammar and syntax
UPDATE public.accommodations
SET 
  additional_info = CASE
    -- === LUXURY SUITES WITH PRIVATE BATHROOMS ===
    WHEN title = 'The Dovecote' THEN 
      'Luxury first-floor suite • Private giant round tub on ground floor • Bluetooth amplifier • Premium amenities'
    
    WHEN title = 'The Hearth' THEN 
      'King bed • Private en-suite bathroom • Working fireplace • Premium castle suite'
    
    WHEN title = 'Writer''s Room' OR title = 'Writers Room' THEN 
      'Queen bed • Private en-suite bathroom • Writing desk • Mountain views • Quiet workspace'
    
    WHEN title = 'Valleyview Room' THEN 
      'Queen bed • Private en-suite bathroom • Stunning valley views • Private balcony'
    
    -- === MICROCABINS (SHARED BATHROOMS) ===
    WHEN title = 'Microcabin' OR title LIKE 'Microcabin%' THEN 
      'Cozy double bed • Shared bathroom facilities nearby • Electricity • Heating • Compact eco-design'
    
    -- === GLAMPING OPTIONS (SHARED BATHROOMS) ===
    WHEN title = 'The Yurt' THEN 
      'Spacious king bed • Shared bathroom facilities • Wood stove heating • Authentic Mongolian yurt'
    
    WHEN title = 'A-Frame Pod' THEN 
      'Double bed • Shared bathroom facilities • Unique A-frame architecture • Forest setting'
    
    -- === BELL TENTS (SHARED BATHROOMS) ===
    WHEN title = '4 Meter Bell Tent' OR title = '4m Bell Tent' THEN 
      'Double mattress • Shared bathroom facilities • Canvas glamping • Garden location'
    
    WHEN title = '5 Meter Bell Tent' OR title = '5m Bell Tent' THEN 
      'Queen mattress • Shared bathroom facilities • Spacious canvas glamping • Garden location'
    
    -- === TIPIS (SHARED BATHROOMS) ===
    WHEN title = '2.2 Meter Tipi' OR title = '2.2m Tipi' THEN 
      'Single mattress • Shared bathroom facilities • Traditional Native American style tipi'
    
    WHEN title = 'Single Tipi' THEN 
      'Single mattress • Shared bathroom facilities • Cozy solo tipi experience'
    
    -- === DORMITORIES (SHARED BATHROOMS) ===
    WHEN title = '3-Bed Dorm' OR title = '3 Bed Dorm' THEN 
      'Single bed in 3-person room • Shared bathrooms • Personal locker • Social atmosphere'
    
    WHEN title = '6-Bed Dorm' OR title = '6 Bed Dorm' THEN 
      'Single bed in 6-person room • Shared bathrooms • Personal locker • Budget-friendly option'
    
    WHEN title = 'Wedding Hall Dorm' THEN 
      'Single bed in historic wedding hall • Shared bathrooms • Unique communal experience • Historic architecture'
    
    WHEN title = 'Shared Dorm' OR title = 'Mixed Dorm' THEN 
      'Single bed in shared dormitory • Shared bathrooms • Budget accommodation • Meet other travelers'
    
    -- === CAMPING & PARKING (SHARED FACILITIES) ===
    WHEN title = 'Your Own Tent' OR title = 'BYO Tent' OR title = 'Bring Your Own Tent' THEN 
      'Bring your own tent • Shared bathroom facilities • Access to all castle amenities • Choose your spot'
    
    WHEN title = 'Van Parking' OR title = 'RV Parking' OR title = 'Campervan Spot' THEN 
      'Van/RV parking spot • Shared bathroom facilities • Electric hookup available • Water access'
    
    -- === SPECIAL ARRANGEMENTS ===
    WHEN title = 'Staying with somebody' OR title = 'Guest of Resident' THEN 
      'Staying as guest of another participant • Bathroom arrangements vary • Contact your host for details'
    
    -- === GARDEN DECOMPRESSION ===
    WHEN title = 'Garden Decompression (No Castle Accommodation)' THEN
      'Portugal garden retreat only • No castle accommodation included • Separate booking'
    
    -- Keep existing if not matched
    ELSE 
      -- Clean up common issues in existing descriptions
      REGEXP_REPLACE(
        REGEXP_REPLACE(
          REGEXP_REPLACE(
            COALESCE(additional_info, ''),
            '\s+', ' ', 'g'  -- Fix multiple spaces
          ),
          '([a-z])([A-Z])', '\1 \2', 'g'  -- Fix missing spaces between words
        ),
        '•\s*•+', '•', 'g'  -- Fix duplicate bullet points
      )
  END,
  updated_at = NOW()
WHERE title IS NOT NULL;

-- Now intelligently set bathroom_type based on the descriptions
UPDATE public.accommodations
SET bathroom_type = CASE
  -- === PRIVATE BATHROOMS ===
  -- Look for keywords: "private", "en-suite", "ensuite", "own bathroom"
  WHEN additional_info ~* '(private|en-suite|ensuite|own).*(bath|shower|tub)' THEN 'private'
  WHEN title IN ('The Hearth', 'Writer''s Room', 'Writers Room', 'Valleyview Room', 'The Dovecote') THEN 'private'
  
  -- === SHARED BATHROOMS ===
  -- Look for keywords: "shared", "communal", "facilities"
  WHEN additional_info ~* '(shared|communal).*(bath|shower|facilities)' THEN 'shared'
  WHEN title LIKE '%Dorm%' THEN 'shared'
  WHEN title LIKE '%Microcabin%' THEN 'shared'
  WHEN title LIKE '%Tent%' THEN 'shared'
  WHEN title LIKE '%Tipi%' THEN 'shared'
  WHEN title IN ('The Yurt', 'A-Frame Pod', 'Van Parking', 'RV Parking', 'Campervan Spot') THEN 'shared'
  
  -- === NO BATHROOM INFO ===
  WHEN title IN ('Staying with somebody', 'Guest of Resident', 'Garden Decompression (No Castle Accommodation)') THEN 'none'
  
  -- Default to shared if bathroom not mentioned (most common case)
  ELSE COALESCE(bathroom_type, 'shared')
END
WHERE title IS NOT NULL;

-- Fix any rooms that should definitely have private bathrooms based on price/type
UPDATE public.accommodations
SET bathroom_type = 'private'
WHERE base_price >= 200  -- Luxury rooms typically have private bathrooms
  AND bathroom_type != 'private'
  AND title NOT LIKE '%Dorm%'
  AND title NOT LIKE '%Tent%';

-- Create a summary report
DO $$
DECLARE
  total_count INTEGER;
  private_count INTEGER;
  shared_count INTEGER;
  none_count INTEGER;
  private_list TEXT;
  shared_list TEXT;
BEGIN
  SELECT COUNT(*) INTO total_count FROM public.accommodations WHERE title IS NOT NULL;
  SELECT COUNT(*) INTO private_count FROM public.accommodations WHERE bathroom_type = 'private';
  SELECT COUNT(*) INTO shared_count FROM public.accommodations WHERE bathroom_type = 'shared';
  SELECT COUNT(*) INTO none_count FROM public.accommodations WHERE bathroom_type = 'none';
  
  -- Get list of accommodations with private bathrooms
  SELECT STRING_AGG(title, ', ' ORDER BY base_price DESC) INTO private_list
  FROM public.accommodations 
  WHERE bathroom_type = 'private';
  
  -- Get sample of shared bathroom accommodations
  SELECT STRING_AGG(title, ', ' ORDER BY title) INTO shared_list
  FROM (
    SELECT title FROM public.accommodations 
    WHERE bathroom_type = 'shared' 
    ORDER BY title 
    LIMIT 10
  ) t;
  
  RAISE NOTICE '';
  RAISE NOTICE '=== ACCOMMODATION BATHROOM REPORT ===';
  RAISE NOTICE 'Total accommodations: %', total_count;
  RAISE NOTICE '';
  RAISE NOTICE 'Private bathrooms (% rooms): %', private_count, private_list;
  RAISE NOTICE '';
  RAISE NOTICE 'Shared bathrooms (% rooms)', shared_count;
  RAISE NOTICE 'Sample: %', shared_list;
  RAISE NOTICE '';
  RAISE NOTICE 'No bathroom info: %', none_count;
  RAISE NOTICE '===================================';
END $$;

-- Ensure indexes exist for performance
CREATE INDEX IF NOT EXISTS idx_accommodations_bathroom_type 
ON public.accommodations(bathroom_type) 
WHERE bathroom_type IS NOT NULL;

CREATE INDEX IF NOT EXISTS idx_accommodations_base_price
ON public.accommodations(base_price)
WHERE base_price IS NOT NULL;

-- Add a constraint to ensure bathroom_type is always set for bookable rooms
ALTER TABLE public.accommodations 
DROP CONSTRAINT IF EXISTS check_bathroom_type_required;

ALTER TABLE public.accommodations 
ADD CONSTRAINT check_bathroom_type_required
CHECK (
  (is_archived = true) OR 
  (bathroom_type IS NOT NULL)
);

COMMIT;