-- Force PostgREST to reload its schema cache
-- Run this in Supabase SQL Editor

-- Method 1: Send reload notification
NOTIFY pgrst, 'reload schema';

-- Method 2: Make a minor schema change to trigger reload
COMMENT ON TABLE public.bookings IS 'Bookings table - schema refreshed';
COMMENT ON TABLE public.payments IS 'Payments table - schema refreshed';

-- Verify the columns exist
SELECT 
    table_name,
    column_name,
    data_type,
    is_nullable
FROM 
    information_schema.columns
WHERE 
    table_schema = 'public' 
    AND table_name IN ('bookings', 'payments')
    AND column_name IN ('accommodation_price', 'payment_intent_id', 'amount', 'metadata')
ORDER BY 
    table_name, column_name;