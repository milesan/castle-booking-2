-- Safe fix for accommodation_type enum issue
-- This handles cases where enum exists with different values

-- 1. First, let's see what we're dealing with
DO $$
DECLARE
    enum_exists boolean;
    has_room_value boolean;
BEGIN
    -- Check if enum exists
    SELECT EXISTS (
        SELECT 1 FROM pg_type WHERE typname = 'accommodation_type'
    ) INTO enum_exists;
    
    IF enum_exists THEN
        -- Check if 'room' value exists in enum
        SELECT EXISTS (
            SELECT 1 
            FROM pg_enum e
            JOIN pg_type t ON e.enumtypid = t.oid
            WHERE t.typname = 'accommodation_type'
            AND e.enumlabel = 'room'
        ) INTO has_room_value;
        
        IF NOT has_room_value THEN
            -- Add missing values to existing enum
            -- Note: We can't check each one individually in a DO block easily,
            -- so we'll use exception handling
            
            BEGIN
                ALTER TYPE accommodation_type ADD VALUE IF NOT EXISTS 'room';
            EXCEPTION WHEN others THEN
                RAISE NOTICE 'Could not add room to enum: %', SQLERRM;
            END;
            
            BEGIN
                ALTER TYPE accommodation_type ADD VALUE IF NOT EXISTS 'dorm';
            EXCEPTION WHEN others THEN
                RAISE NOTICE 'Could not add dorm to enum: %', SQLERRM;
            END;
            
            BEGIN
                ALTER TYPE accommodation_type ADD VALUE IF NOT EXISTS 'cabin';
            EXCEPTION WHEN others THEN
                RAISE NOTICE 'Could not add cabin to enum: %', SQLERRM;
            END;
            
            BEGIN
                ALTER TYPE accommodation_type ADD VALUE IF NOT EXISTS 'tent';
            EXCEPTION WHEN others THEN
                RAISE NOTICE 'Could not add tent to enum: %', SQLERRM;
            END;
            
            BEGIN
                ALTER TYPE accommodation_type ADD VALUE IF NOT EXISTS 'parking';
            EXCEPTION WHEN others THEN
                RAISE NOTICE 'Could not add parking to enum: %', SQLERRM;
            END;
            
            BEGIN
                ALTER TYPE accommodation_type ADD VALUE IF NOT EXISTS 'addon';
            EXCEPTION WHEN others THEN
                RAISE NOTICE 'Could not add addon to enum: %', SQLERRM;
            END;
        END IF;
    ELSE
        -- Create the enum if it doesn't exist
        CREATE TYPE accommodation_type AS ENUM (
            'room',
            'dorm', 
            'cabin',
            'tent',
            'parking',
            'addon'
        );
        RAISE NOTICE 'Created accommodation_type enum';
    END IF;
END $$;

-- 2. Now check/add the type column to accommodations
DO $$ 
BEGIN
    IF NOT EXISTS (
        SELECT 1 FROM information_schema.columns 
        WHERE table_schema = 'public'
        AND table_name = 'accommodations' 
        AND column_name = 'type'
    ) THEN
        -- First get valid enum values
        CREATE TEMP TABLE valid_types AS
        SELECT enumlabel::text as value
        FROM pg_enum e
        JOIN pg_type t ON e.enumtypid = t.oid
        WHERE t.typname = 'accommodation_type'
        LIMIT 1;
        
        -- Add column with first valid enum value as default
        EXECUTE format('ALTER TABLE public.accommodations ADD COLUMN type accommodation_type NOT NULL DEFAULT %L::accommodation_type',
            (SELECT value FROM valid_types LIMIT 1));
        
        DROP TABLE valid_types;
        RAISE NOTICE 'Added type column to accommodations';
    ELSE
        RAISE NOTICE 'type column already exists';
    END IF;
END $$;

-- 3. Show current enum values to verify
SELECT 
    'accommodation_type enum values:' as info,
    string_agg(enumlabel::text, ', ' ORDER BY enumsortorder) as values
FROM pg_enum e
JOIN pg_type t ON e.enumtypid = t.oid
WHERE t.typname = 'accommodation_type'
GROUP BY t.typname;

-- 4. Update accommodations with safe type values
-- First, let's see what values are available
WITH valid_types AS (
    SELECT enumlabel::text as value
    FROM pg_enum e
    JOIN pg_type t ON e.enumtypid = t.oid
    WHERE t.typname = 'accommodation_type'
)
UPDATE public.accommodations 
SET type = (
    SELECT value::accommodation_type 
    FROM valid_types 
    WHERE value = CASE
        WHEN LOWER(accommodations.title) LIKE '%room%' AND EXISTS (SELECT 1 FROM valid_types WHERE value = 'room') THEN 'room'
        WHEN LOWER(accommodations.title) LIKE '%dorm%' AND EXISTS (SELECT 1 FROM valid_types WHERE value = 'dorm') THEN 'dorm'
        WHEN (LOWER(accommodations.title) LIKE '%cabin%' OR LOWER(accommodations.title) LIKE '%micro%') 
             AND EXISTS (SELECT 1 FROM valid_types WHERE value = 'cabin') THEN 'cabin'
        WHEN (LOWER(accommodations.title) LIKE '%tent%' OR LOWER(accommodations.title) LIKE '%camp%')
             AND EXISTS (SELECT 1 FROM valid_types WHERE value = 'tent') THEN 'tent'
        WHEN (LOWER(accommodations.title) LIKE '%park%' OR LOWER(accommodations.title) LIKE '%van%' OR LOWER(accommodations.title) LIKE '%rv%')
             AND EXISTS (SELECT 1 FROM valid_types WHERE value = 'parking') THEN 'parking'
        ELSE NULL
    END
    LIMIT 1
)
WHERE type IS NULL 
AND EXISTS (
    SELECT 1 FROM valid_types 
    WHERE value = CASE
        WHEN LOWER(accommodations.title) LIKE '%room%' THEN 'room'
        WHEN LOWER(accommodations.title) LIKE '%dorm%' THEN 'dorm'
        WHEN LOWER(accommodations.title) LIKE '%cabin%' OR LOWER(accommodations.title) LIKE '%micro%' THEN 'cabin'
        WHEN LOWER(accommodations.title) LIKE '%tent%' OR LOWER(accommodations.title) LIKE '%camp%' THEN 'tent'
        WHEN LOWER(accommodations.title) LIKE '%park%' OR LOWER(accommodations.title) LIKE '%van%' OR LOWER(accommodations.title) LIKE '%rv%' THEN 'parking'
        ELSE NULL
    END
);

-- If any accommodations still have NULL type, set them to the first available enum value
UPDATE public.accommodations
SET type = (
    SELECT enumlabel::accommodation_type
    FROM pg_enum e
    JOIN pg_type t ON e.enumtypid = t.oid
    WHERE t.typname = 'accommodation_type'
    ORDER BY e.enumsortorder
    LIMIT 1
)
WHERE type IS NULL;