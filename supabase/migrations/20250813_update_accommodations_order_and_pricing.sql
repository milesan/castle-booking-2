-- Update accommodations order, pricing, and add Le Dorm

BEGIN;

-- Add Le Dorm if it doesn't exist
INSERT INTO public.accommodations (
  title,
  base_price,
  capacity,
  additional_info,
  bathroom_type,
  is_available,
  property_location,
  inventory,
  display_order
) VALUES (
  'Le Dorm',
  150,
  1,
  '90x200 mattress with sheet and pillow • Bring your own duvet or sleeping bag • Located in the wedding hall • Shared bathrooms',
  'shared',
  true,
  'castle',
  20, -- Assuming 20 spots
  5 -- Display near the top, after tent/van options
) ON CONFLICT (title) DO UPDATE SET
  base_price = 150,
  additional_info = '90x200 mattress with sheet and pillow • Bring your own duvet or sleeping bag • Located in the wedding hall • Shared bathrooms',
  bathroom_type = 'shared',
  display_order = 5;

-- Update display order to show tent/van first
UPDATE public.accommodations SET display_order = CASE
  WHEN title = 'Your Own Tent' THEN 1
  WHEN title = 'Your Own Van' OR title = 'Van Parking' THEN 2
  WHEN title = 'Single Tipi' THEN 3
  WHEN title = '4 Meter Bell Tent' OR title = '4m Bell Tent' THEN 4
  WHEN title = 'Le Dorm' THEN 5
  -- Glamping options next
  WHEN title LIKE '%Microcabin%' THEN 10
  WHEN title = 'The Yurt' THEN 11
  WHEN title = 'A-Frame Pod' THEN 12
  -- Then all the castle rooms
  ELSE display_order + 20
END
WHERE title IS NOT NULL;

-- Update pricing for bell tent and tipi (fixed prices, not auction)
UPDATE public.accommodations 
SET base_price = 650,
    additional_info = 'Double mattress • Shared bathroom facilities • Canvas glamping • Garden location • Fixed price'
WHERE title IN ('4 Meter Bell Tent', '4m Bell Tent');

UPDATE public.accommodations 
SET base_price = 300,
    additional_info = 'Single mattress • Shared bathroom facilities • Traditional tipi • Fixed price'
WHERE title = 'Single Tipi';

-- Ensure tent and van are marked as free
UPDATE public.accommodations 
SET base_price = 0
WHERE title IN ('Your Own Tent', 'Your Own Van', 'Van Parking');

COMMIT;