-- Add new accommodation options and update existing ones
-- Date: 2025-08-29

BEGIN;

-- First, let's add the new 4M Bell Tent with Castle View (€1000, qty 3)
INSERT INTO accommodations (
  title,
  location,
  base_price,
  rating,
  reviews,
  image_url,
  type,
  capacity,
  is_available,
  is_fungible,
  inventory,
  bathroom_type,
  description,
  additional_info,
  display_order,
  property_location
) VALUES (
  '4M Bell Tent, Castle View',
  'The Garden',
  1000,
  5.0,
  0,
  'https://storage.tally.so/f385d036-6b48-4a0b-b119-2e334c0bc1f0/photo_2023-09-07_18-55-18.jpg',
  'Bell Tent',
  2,
  true,
  true,
  3,
  'shared',
  '4-meter bell tent with panoramic castle views',
  'Premium location • Shared bath facilities • Fits 2 people • Only 3 available',
  4,
  'garden'
) ON CONFLICT (title) DO UPDATE SET
  base_price = EXCLUDED.base_price,
  inventory = EXCLUDED.inventory,
  description = EXCLUDED.description,
  additional_info = EXCLUDED.additional_info;

-- Add 4M Bell Tents Near Castle (€800, qty 12)
INSERT INTO accommodations (
  title,
  location,
  base_price,
  rating,
  reviews,
  image_url,
  type,
  capacity,
  is_available,
  is_fungible,
  inventory,
  bathroom_type,
  description,
  additional_info,
  display_order,
  property_location
) VALUES (
  '4M Bell Tent, Near Castle',
  'The Garden',
  800,
  5.0,
  0,
  'https://storage.tally.so/f385d036-6b48-4a0b-b119-2e334c0bc1f0/photo_2023-09-07_18-55-18.jpg',
  'Bell Tent',
  2,
  true,
  true,
  12,
  'shared',
  '4-meter bell tent close to the castle',
  'Near castle location • Shared bath facilities • Fits 2 people • 12 available',
  5,
  'garden'
) ON CONFLICT (title) DO UPDATE SET
  base_price = EXCLUDED.base_price,
  inventory = EXCLUDED.inventory,
  description = EXCLUDED.description,
  additional_info = EXCLUDED.additional_info;

-- Add Tipis with Ramparts View (€400, qty 15)
INSERT INTO accommodations (
  title,
  location,
  base_price,
  rating,
  reviews,
  image_url,
  type,
  capacity,
  is_available,
  is_fungible,
  inventory,
  bathroom_type,
  description,
  additional_info,
  display_order,
  property_location
) VALUES (
  'Tipi, Ramparts View',
  'The Garden',
  400,
  5.0,
  0,
  'https://storage.tally.so/f385d036-6b48-4a0b-b119-2e334c0bc1f0/photo_2023-09-07_18-55-18.jpg',
  'Tipi',
  2,
  true,
  true,
  15,
  'shared',
  'Traditional tipi with ramparts view',
  'Ramparts view • Shared bathroom facilities • Traditional tipi • 15 available',
  6,
  'garden'
) ON CONFLICT (title) DO UPDATE SET
  base_price = EXCLUDED.base_price,
  inventory = EXCLUDED.inventory,
  description = EXCLUDED.description,
  additional_info = EXCLUDED.additional_info;

-- Add Other Tipis (€250, qty 2)
INSERT INTO accommodations (
  title,
  location,
  base_price,
  rating,
  reviews,
  image_url,
  type,
  capacity,
  is_available,
  is_fungible,
  inventory,
  bathroom_type,
  description,
  additional_info,
  display_order,
  property_location
) VALUES (
  'Tipi, Garden Location',
  'The Garden',
  250,
  5.0,
  0,
  'https://storage.tally.so/f385d036-6b48-4a0b-b119-2e334c0bc1f0/photo_2023-09-07_18-55-18.jpg',
  'Tipi',
  2,
  true,
  true,
  2,
  'shared',
  'Traditional tipi in garden setting',
  'Garden location • Shared bathroom facilities • Traditional tipi • Only 2 available',
  7,
  'garden'
) ON CONFLICT (title) DO UPDATE SET
  base_price = EXCLUDED.base_price,
  inventory = EXCLUDED.inventory,
  description = EXCLUDED.description,
  additional_info = EXCLUDED.additional_info;

-- Update existing 4M Bell Tent to indicate 2-3 minute walk to castle and set price to €600
UPDATE accommodations 
SET 
  base_price = 600,
  description = '4-meter bell tent in garden location',
  additional_info = 'Garden location • 2-3 minute walk to castle • Shared bath facilities • Fits 2 people'
WHERE (title = '4 Meter Bell Tent' OR title = '4m Bell Tent')
  AND type = 'Bell Tent'
  AND title NOT LIKE '%Castle View%'
  AND title NOT LIKE '%Near Castle%';

COMMIT;