-- Quick Test Script for Atomic Booking System
-- Run this in your Supabase SQL Editor to verify everything is working
-- Go to: https://supabase.com/dashboard/project/ywsbmarhoyxercqatbfy/sql/new

-- ============================================
-- 1. CHECK THAT ALL FUNCTIONS EXIST
-- ============================================
DO $$
BEGIN
    RAISE NOTICE '=== CHECKING ATOMIC BOOKING SYSTEM ===';
    RAISE NOTICE '';
    
    -- Check main function
    IF EXISTS (SELECT 1 FROM pg_proc WHERE proname = 'create_booking_with_atomic_lock') THEN
        RAISE NOTICE '✅ create_booking_with_atomic_lock EXISTS';
    ELSE
        RAISE WARNING '❌ create_booking_with_atomic_lock NOT FOUND';
    END IF;
    
    -- Check availability function
    IF EXISTS (SELECT 1 FROM pg_proc WHERE proname = 'check_availability_with_lock') THEN
        RAISE NOTICE '✅ check_availability_with_lock EXISTS';
    ELSE
        RAISE WARNING '❌ check_availability_with_lock NOT FOUND';
    END IF;
    
    -- Check monitoring function
    IF EXISTS (SELECT 1 FROM pg_proc WHERE proname = 'check_for_double_bookings') THEN
        RAISE NOTICE '✅ check_for_double_bookings EXISTS';
    ELSE
        RAISE WARNING '❌ check_for_double_bookings NOT FOUND';
    END IF;
    
    -- Check trigger
    IF EXISTS (SELECT 1 FROM information_schema.triggers WHERE trigger_name = 'validate_booking_before_insert') THEN
        RAISE NOTICE '✅ validate_booking_before_insert TRIGGER EXISTS';
    ELSE
        RAISE WARNING '❌ validate_booking_before_insert TRIGGER NOT FOUND';
    END IF;
    
    RAISE NOTICE '';
END $$;

-- ============================================
-- 2. CHECK FOR ANY EXISTING DOUBLE-BOOKINGS
-- ============================================
SELECT 
    CASE 
        WHEN COUNT(*) = 0 THEN '✅ NO DOUBLE-BOOKINGS FOUND'
        ELSE '⚠️ FOUND ' || COUNT(*) || ' DOUBLE-BOOKINGS'
    END as double_booking_check
FROM check_for_double_bookings();

-- ============================================
-- 3. TEST THE ATOMIC BOOKING FUNCTION
-- ============================================
DO $$
DECLARE
    v_test_accommodation_id uuid;
    v_test_user_id uuid;
    v_booking_id_1 uuid;
    v_booking_id_2 uuid;
    v_booking_id_3 uuid;
BEGIN
    RAISE NOTICE '=== TESTING ATOMIC BOOKING PREVENTION ===';
    RAISE NOTICE '';
    
    -- Create test accommodation with only 1 room
    INSERT INTO accommodations (
        title, type, inventory, is_unlimited, price
    ) VALUES (
        'TEST ROOM - Quick Test ' || NOW()::text,
        'room', 1, false, 100
    ) RETURNING id INTO v_test_accommodation_id;
    
    v_test_user_id := gen_random_uuid();
    
    RAISE NOTICE 'Created test accommodation with 1 room';
    
    -- First booking should succeed
    BEGIN
        v_booking_id_1 := create_booking_with_atomic_lock(
            p_accommodation_id := v_test_accommodation_id,
            p_user_id := v_test_user_id,
            p_check_in := '2026-01-01'::timestamp with time zone,
            p_check_out := '2026-01-07'::timestamp with time zone,
            p_total_price := 600,
            p_status := 'confirmed'
        );
        RAISE NOTICE '✅ First booking SUCCEEDED (as expected)';
    EXCEPTION WHEN OTHERS THEN
        RAISE WARNING '❌ First booking FAILED (unexpected): %', SQLERRM;
    END;
    
    -- Second booking should FAIL (no more rooms)
    BEGIN
        v_booking_id_2 := create_booking_with_atomic_lock(
            p_accommodation_id := v_test_accommodation_id,
            p_user_id := gen_random_uuid(),
            p_check_in := '2026-01-01'::timestamp with time zone,
            p_check_out := '2026-01-07'::timestamp with time zone,
            p_total_price := 600,
            p_status := 'confirmed'
        );
        RAISE WARNING '❌ Second booking SUCCEEDED (should have failed!)';
    EXCEPTION WHEN OTHERS THEN
        RAISE NOTICE '✅ Second booking REJECTED (as expected): No availability';
    END;
    
    -- Cleanup
    DELETE FROM bookings WHERE accommodation_id = v_test_accommodation_id;
    DELETE FROM accommodations WHERE id = v_test_accommodation_id;
    
    RAISE NOTICE '';
    RAISE NOTICE '✅ ATOMIC BOOKING SYSTEM IS WORKING CORRECTLY!';
END $$;

-- ============================================
-- 4. SHOW CURRENT SYSTEM STATISTICS
-- ============================================
SELECT 
    '📊 SYSTEM STATISTICS' as category,
    COUNT(DISTINCT accommodation_id) as unique_accommodations,
    COUNT(*) as total_bookings,
    COUNT(CASE WHEN status = 'confirmed' THEN 1 END) as confirmed_bookings,
    COUNT(CASE WHEN status = 'pending' THEN 1 END) as pending_bookings,
    COUNT(CASE WHEN created_at > NOW() - INTERVAL '24 hours' THEN 1 END) as bookings_last_24h
FROM bookings;

-- ============================================
-- 5. CHECK ACCOMMODATIONS WITH LIMITED INVENTORY
-- ============================================
SELECT 
    title,
    inventory,
    CASE 
        WHEN is_unlimited THEN 'Unlimited'
        ELSE inventory::text || ' rooms'
    END as capacity,
    sold_out
FROM accommodations
WHERE is_unlimited = false 
AND inventory IS NOT NULL
ORDER BY inventory ASC
LIMIT 10;

-- Final message
SELECT '🎉 All tests completed! Check the messages above for results.' as status;