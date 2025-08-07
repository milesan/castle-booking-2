-- Fix accommodation_type enum issue
-- This migration ensures the accommodation_type enum exists with the correct values

-- First check if the type exists and drop it if it does (to ensure clean state)
DO $$ 
BEGIN
    -- Check if the enum type exists
    IF EXISTS (SELECT 1 FROM pg_type WHERE typname = 'accommodation_type') THEN
        -- Check if it's being used in any columns
        IF NOT EXISTS (
            SELECT 1 
            FROM pg_attribute a
            JOIN pg_class c ON a.attrelid = c.oid
            JOIN pg_type t ON a.atttypid = t.oid
            WHERE t.typname = 'accommodation_type'
        ) THEN
            -- Safe to drop if not in use
            DROP TYPE accommodation_type;
        END IF;
    END IF;
END $$;

-- Create the enum type if it doesn't exist
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

-- Also ensure booking_status enum exists
DO $$ 
BEGIN
    IF NOT EXISTS (SELECT 1 FROM pg_type WHERE typname = 'booking_status') THEN
        CREATE TYPE booking_status AS ENUM (
            'pending',
            'confirmed', 
            'cancelled'
        );
    END IF;
END $$;

-- Add the type column to accommodations table if it doesn't exist
DO $$ 
BEGIN
    IF NOT EXISTS (
        SELECT 1 
        FROM information_schema.columns 
        WHERE table_name = 'accommodations' 
        AND column_name = 'type'
    ) THEN
        ALTER TABLE accommodations 
        ADD COLUMN type accommodation_type NOT NULL DEFAULT 'room';
    END IF;
END $$;