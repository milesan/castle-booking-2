-- Fix payments table to allow NULL booking_id for pending payments
-- Run this in Supabase SQL Editor

-- Allow NULL booking_id in payments table
ALTER TABLE public.payments 
ALTER COLUMN booking_id DROP NOT NULL;

-- Add comment to explain why booking_id can be NULL
COMMENT ON COLUMN public.payments.booking_id IS 'Reference to the booking. Can be NULL for pending payments that are created before the booking.';

-- Verify the change
SELECT 
    column_name,
    is_nullable,
    data_type
FROM 
    information_schema.columns
WHERE 
    table_schema = 'public' 
    AND table_name = 'payments'
    AND column_name = 'booking_id';