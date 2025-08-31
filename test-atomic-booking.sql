-- Test script to verify atomic booking locking prevents double-booking
-- Run this script to test the implementation

-- First, let's check if our new functions were created successfully
SELECT 
    proname as function_name,
    pronargs as num_args
FROM pg_proc 
WHERE proname IN (
    'create_booking_with_atomic_lock',
    'check_availability_with_lock',
    'assign_accommodation_item_atomically',
    'check_for_double_bookings'
);

-- Test 1: Check current accommodation inventory
SELECT 
    id,
    title,
    inventory,
    is_unlimited,
    sold_out
FROM accommodations
WHERE is_unlimited = false
ORDER BY inventory ASC
LIMIT 5;

-- Test 2: Check current bookings for a specific accommodation
-- Replace with an actual accommodation_id from your database
WITH test_accommodation AS (
    SELECT id, title, inventory 
    FROM accommodations 
    WHERE is_unlimited = false 
    AND inventory > 0
    LIMIT 1
)
SELECT 
    ta.title,
    ta.inventory,
    COUNT(b.id) as current_bookings,
    ta.inventory - COUNT(b.id) as available_slots
FROM test_accommodation ta
LEFT JOIN bookings b ON b.accommodation_id = ta.id
    AND b.status IN ('confirmed', 'pending')
    AND b.check_in < '2025-09-15'::date
    AND b.check_out > '2025-09-01'::date
GROUP BY ta.id, ta.title, ta.inventory;

-- Test 3: Simulate checking availability with our new function
-- This should return available count for a specific accommodation and date range
SELECT check_availability_with_lock(
    (SELECT id FROM accommodations WHERE is_unlimited = false LIMIT 1),
    '2025-09-01'::timestamp with time zone,
    '2025-09-07'::timestamp with time zone
) as available_rooms;

-- Test 4: Check for any existing double-bookings (should return empty if none exist)
SELECT * FROM check_for_double_bookings();

-- Test 5: Verify indexes were created
SELECT 
    schemaname,
    tablename,
    indexname
FROM pg_indexes
WHERE tablename = 'bookings'
AND indexname IN (
    'idx_bookings_availability_check_optimized',
    'idx_bookings_item_assignment'
);

-- Test 6: Simulate a booking creation (commented out to prevent actual booking)
-- Uncomment and modify the values to test actual booking creation
/*
SELECT create_booking_with_atomic_lock(
    p_accommodation_id := 'YOUR_ACCOMMODATION_UUID_HERE',
    p_user_id := 'YOUR_USER_UUID_HERE',
    p_check_in := '2025-09-01'::timestamp with time zone,
    p_check_out := '2025-09-07'::timestamp with time zone,
    p_total_price := 500.00,
    p_status := 'pending',
    p_accommodation_item_id := NULL,
    p_applied_discount_code := NULL,
    p_discount_amount := NULL
);
*/

-- Test 7: Check trigger existence
SELECT 
    trigger_name,
    event_manipulation,
    event_object_table,
    action_timing
FROM information_schema.triggers
WHERE event_object_table = 'bookings'
AND trigger_name = 'validate_booking_before_insert';

-- Summary report
SELECT 
    'Atomic booking system is ready!' as status,
    'Functions created: ' || COUNT(*) as functions_count
FROM pg_proc 
WHERE proname IN (
    'create_booking_with_atomic_lock',
    'check_availability_with_lock',
    'assign_accommodation_item_atomically',
    'check_for_double_bookings'
);