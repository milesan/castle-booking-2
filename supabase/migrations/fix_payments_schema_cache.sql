-- Fix payments table schema cache issue
-- Run this in Supabase SQL Editor

-- 1. First check if the column exists
SELECT 
    column_name,
    data_type,
    is_nullable,
    column_default
FROM 
    information_schema.columns
WHERE 
    table_schema = 'public' 
    AND table_name = 'payments'
    AND column_name = 'amount_paid';

-- 2. If it doesn't exist, add it (shouldn't be needed based on extracted_tables.sql)
DO $$
BEGIN
    IF NOT EXISTS (
        SELECT 1 
        FROM information_schema.columns 
        WHERE table_schema = 'public' 
        AND table_name = 'payments' 
        AND column_name = 'amount_paid'
    ) THEN
        ALTER TABLE public.payments 
        ADD COLUMN amount_paid numeric(10,2) NOT NULL DEFAULT 0;
    END IF;
END $$;

-- 3. Also ensure booking_id can be NULL (from our previous fix)
ALTER TABLE public.payments 
ALTER COLUMN booking_id DROP NOT NULL;

-- 4. Reload the schema cache by calling PostgREST's reload endpoint
-- This is done automatically by Supabase, but we can force it by making a schema change
-- Add a comment to force schema reload
COMMENT ON TABLE public.payments IS 'Payment records for bookings - schema refreshed';

-- 5. Verify the final structure
SELECT 
    column_name,
    data_type,
    is_nullable,
    column_default
FROM 
    information_schema.columns
WHERE 
    table_schema = 'public' 
    AND table_name = 'payments'
ORDER BY ordinal_position;