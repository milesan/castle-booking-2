-- Comprehensive fix for accommodations schema based on backup
-- This migration ensures all required types and columns exist

-- 1. Create/fix accommodation_type enum
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
    END IF;
END $$;

-- 2. Add missing columns to accommodations table if they don't exist
DO $$ 
BEGIN
    -- Add type column if missing
    IF NOT EXISTS (
        SELECT 1 FROM information_schema.columns 
        WHERE table_name = 'accommodations' 
        AND column_name = 'type'
    ) THEN
        ALTER TABLE accommodations 
        ADD COLUMN type accommodation_type NOT NULL DEFAULT 'room';
    END IF;

    -- Add inventory column if missing
    IF NOT EXISTS (
        SELECT 1 FROM information_schema.columns 
        WHERE table_name = 'accommodations' 
        AND column_name = 'inventory'
    ) THEN
        ALTER TABLE accommodations 
        ADD COLUMN inventory integer CHECK (inventory >= 0);
        
        -- Set default inventory based on existing data
        UPDATE accommodations 
        SET inventory = CASE 
            WHEN is_unlimited THEN 999
            WHEN is_fungible THEN COALESCE(inventory_count, 10)
            ELSE COALESCE(inventory_count, 1)
        END
        WHERE inventory IS NULL;
    END IF;

    -- Add bed_size column if missing
    IF NOT EXISTS (
        SELECT 1 FROM information_schema.columns 
        WHERE table_name = 'accommodations' 
        AND column_name = 'bed_size'
    ) THEN
        ALTER TABLE accommodations 
        ADD COLUMN bed_size text;
    END IF;

    -- Add bathroom_type column if missing
    IF NOT EXISTS (
        SELECT 1 FROM information_schema.columns 
        WHERE table_name = 'accommodations' 
        AND column_name = 'bathroom_type'
    ) THEN
        ALTER TABLE accommodations 
        ADD COLUMN bathroom_type text DEFAULT 'none';
    END IF;

    -- Add bathrooms column if missing
    IF NOT EXISTS (
        SELECT 1 FROM information_schema.columns 
        WHERE table_name = 'accommodations' 
        AND column_name = 'bathrooms'
    ) THEN
        ALTER TABLE accommodations 
        ADD COLUMN bathrooms numeric DEFAULT 0;
    END IF;

    -- Add capacity column if missing
    IF NOT EXISTS (
        SELECT 1 FROM information_schema.columns 
        WHERE table_name = 'accommodations' 
        AND column_name = 'capacity'
    ) THEN
        ALTER TABLE accommodations 
        ADD COLUMN capacity integer DEFAULT 1 NOT NULL;
    END IF;

    -- Ensure base_price is REAL not INTEGER
    IF EXISTS (
        SELECT 1 FROM information_schema.columns 
        WHERE table_name = 'accommodations' 
        AND column_name = 'base_price'
        AND data_type = 'integer'
    ) THEN
        ALTER TABLE accommodations 
        ALTER COLUMN base_price TYPE real USING base_price::real;
    END IF;
END $$;

-- 3. Add check constraints if they don't exist
DO $$
BEGIN
    IF NOT EXISTS (
        SELECT 1 FROM pg_constraint 
        WHERE conname = 'accommodations_base_price_check'
    ) THEN
        ALTER TABLE accommodations
        ADD CONSTRAINT accommodations_base_price_check 
        CHECK (base_price >= 0::double precision);
    END IF;

    IF NOT EXISTS (
        SELECT 1 FROM pg_constraint 
        WHERE conname = 'accommodations_inventory_check'
    ) THEN
        ALTER TABLE accommodations
        ADD CONSTRAINT accommodations_inventory_check 
        CHECK (inventory >= 0);
    END IF;
END $$;

-- 4. Update existing accommodations with reasonable type values based on their names
UPDATE accommodations 
SET type = CASE
    WHEN LOWER(title) LIKE '%room%' THEN 'room'::accommodation_type
    WHEN LOWER(title) LIKE '%dorm%' THEN 'dorm'::accommodation_type
    WHEN LOWER(title) LIKE '%cabin%' OR LOWER(title) LIKE '%micro%' THEN 'cabin'::accommodation_type
    WHEN LOWER(title) LIKE '%tent%' OR LOWER(title) LIKE '%camp%' THEN 'tent'::accommodation_type
    WHEN LOWER(title) LIKE '%park%' OR LOWER(title) LIKE '%van%' OR LOWER(title) LIKE '%rv%' THEN 'parking'::accommodation_type
    ELSE 'room'::accommodation_type
END
WHERE type IS NULL;