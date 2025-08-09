-- Run this SQL in Supabase Dashboard SQL Editor
-- This fixes the accommodation_type enum issue

-- 1. Create accommodation_type enum if it doesn't exist
DO $$ 
BEGIN
    IF NOT EXISTS (SELECT 1 FROM pg_type WHERE typname = 'accommodation_type') THEN
        CREATE TYPE accommodation_type AS ENUM (
            'room',
            'dorm', 
            'cabin',
            'tent',
            'parking',
            'addon'
        );
        RAISE NOTICE 'Created accommodation_type enum';
    ELSE
        RAISE NOTICE 'accommodation_type enum already exists';
    END IF;
END $$;

-- 2. Check and add missing columns to accommodations table
DO $$ 
BEGIN
    -- Add type column if missing
    IF NOT EXISTS (
        SELECT 1 FROM information_schema.columns 
        WHERE table_schema = 'public'
        AND table_name = 'accommodations' 
        AND column_name = 'type'
    ) THEN
        ALTER TABLE public.accommodations 
        ADD COLUMN type accommodation_type NOT NULL DEFAULT 'room';
        RAISE NOTICE 'Added type column to accommodations';
    ELSE
        RAISE NOTICE 'type column already exists';
    END IF;

    -- Add inventory column if missing
    IF NOT EXISTS (
        SELECT 1 FROM information_schema.columns 
        WHERE table_schema = 'public'
        AND table_name = 'accommodations' 
        AND column_name = 'inventory'
    ) THEN
        ALTER TABLE public.accommodations 
        ADD COLUMN inventory integer CHECK (inventory >= 0);
        
        -- Set default inventory based on existing data
        UPDATE public.accommodations 
        SET inventory = CASE 
            WHEN is_unlimited THEN 999
            ELSE COALESCE(inventory_count, 1)
        END
        WHERE inventory IS NULL;
        
        RAISE NOTICE 'Added inventory column to accommodations';
    ELSE
        RAISE NOTICE 'inventory column already exists';
    END IF;

    -- Ensure base_price is REAL/FLOAT not INTEGER
    IF EXISTS (
        SELECT 1 FROM information_schema.columns 
        WHERE table_schema = 'public'
        AND table_name = 'accommodations' 
        AND column_name = 'base_price'
        AND data_type = 'integer'
    ) THEN
        ALTER TABLE public.accommodations 
        ALTER COLUMN base_price TYPE real USING base_price::real;
        RAISE NOTICE 'Converted base_price from integer to real';
    END IF;
END $$;

-- 3. Update existing accommodations with reasonable type values
UPDATE public.accommodations 
SET type = CASE
    WHEN LOWER(title) LIKE '%room%' THEN 'room'::accommodation_type
    WHEN LOWER(title) LIKE '%dorm%' THEN 'dorm'::accommodation_type
    WHEN LOWER(title) LIKE '%cabin%' OR LOWER(title) LIKE '%micro%' THEN 'cabin'::accommodation_type
    WHEN LOWER(title) LIKE '%tent%' OR LOWER(title) LIKE '%camp%' THEN 'tent'::accommodation_type
    WHEN LOWER(title) LIKE '%park%' OR LOWER(title) LIKE '%van%' OR LOWER(title) LIKE '%rv%' THEN 'parking'::accommodation_type
    ELSE 'room'::accommodation_type
END
WHERE type IS NULL;

-- 4. Show current state
SELECT 
    column_name, 
    data_type, 
    is_nullable,
    column_default
FROM information_schema.columns 
WHERE table_schema = 'public' 
AND table_name = 'accommodations'
ORDER BY ordinal_position;

-- 5. Show enum values
SELECT enumlabel 
FROM pg_enum 
WHERE enumtypid = 'accommodation_type'::regtype
ORDER BY enumsortorder;