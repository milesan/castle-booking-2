-- Fix accommodation_type enum by adding missing values
-- Current values: cabin, camping, dorm
-- Need to add: room, tent, parking, addon

-- Add missing values to the accommodation_type enum
ALTER TYPE public.accommodation_type ADD VALUE IF NOT EXISTS 'room';
ALTER TYPE public.accommodation_type ADD VALUE IF NOT EXISTS 'tent';
ALTER TYPE public.accommodation_type ADD VALUE IF NOT EXISTS 'parking';
ALTER TYPE public.accommodation_type ADD VALUE IF NOT EXISTS 'addon';

-- Verify the enum now has all values
SELECT 
    'accommodation_type enum values after update:' as info,
    string_agg(enumlabel::text, ', ' ORDER BY enumsortorder) as values
FROM pg_enum e
JOIN pg_type t ON e.enumtypid = t.oid
WHERE t.typname = 'accommodation_type'
GROUP BY t.typname;

-- Now add the type column if it doesn't exist
DO $$ 
BEGIN
    IF NOT EXISTS (
        SELECT 1 FROM information_schema.columns 
        WHERE table_schema = 'public'
        AND table_name = 'accommodations' 
        AND column_name = 'type'
    ) THEN
        ALTER TABLE public.accommodations 
        ADD COLUMN type public.accommodation_type NOT NULL DEFAULT 'room';
        RAISE NOTICE 'Added type column to accommodations';
    ELSE
        RAISE NOTICE 'type column already exists';
    END IF;
END $$;

-- Update existing accommodations with appropriate type values
UPDATE public.accommodations 
SET type = CASE
    WHEN LOWER(title) LIKE '%room%' THEN 'room'::accommodation_type
    WHEN LOWER(title) LIKE '%dorm%' THEN 'dorm'::accommodation_type
    WHEN LOWER(title) LIKE '%cabin%' OR LOWER(title) LIKE '%micro%' THEN 'cabin'::accommodation_type
    WHEN LOWER(title) LIKE '%tent%' THEN 'tent'::accommodation_type
    WHEN LOWER(title) LIKE '%camp%' OR LOWER(title) LIKE '%spot%' THEN 'camping'::accommodation_type
    WHEN LOWER(title) LIKE '%park%' OR LOWER(title) LIKE '%van%' OR LOWER(title) LIKE '%rv%' THEN 'parking'::accommodation_type
    ELSE 'room'::accommodation_type
END
WHERE type IS NULL;

-- Show the results
SELECT 
    id,
    title,
    type,
    base_price
FROM public.accommodations
ORDER BY title;