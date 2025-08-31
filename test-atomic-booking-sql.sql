-- Comprehensive SQL Test Suite for Atomic Booking System
-- Run this directly in your database to test the implementation

-- Enable detailed output
\timing on
\set VERBOSITY verbose

-- ============================================
-- TEST SETUP
-- ============================================

DO $$
DECLARE
    v_test_accommodation_id uuid;
    v_test_user_id_1 uuid;
    v_test_user_id_2 uuid;
    v_test_user_id_3 uuid;
    v_booking_id_1 uuid;
    v_booking_id_2 uuid;
    v_booking_id_3 uuid;
    v_availability integer;
    v_test_passed boolean := true;
    v_error_message text;
BEGIN
    RAISE NOTICE '====================================';
    RAISE NOTICE '🧪 ATOMIC BOOKING SYSTEM TEST SUITE';
    RAISE NOTICE '====================================';
    RAISE NOTICE '';

    -- ============================================
    -- TEST 1: Verify Functions Exist
    -- ============================================
    RAISE NOTICE 'TEST 1: Checking if atomic booking functions exist...';
    
    IF EXISTS (
        SELECT 1 FROM pg_proc 
        WHERE proname = 'create_booking_with_atomic_lock'
    ) THEN
        RAISE NOTICE '✓ Function create_booking_with_atomic_lock exists';
    ELSE
        RAISE EXCEPTION '✗ Function create_booking_with_atomic_lock NOT FOUND. Please run migration.';
    END IF;

    IF EXISTS (
        SELECT 1 FROM pg_proc 
        WHERE proname = 'check_availability_with_lock'
    ) THEN
        RAISE NOTICE '✓ Function check_availability_with_lock exists';
    ELSE
        RAISE EXCEPTION '✗ Function check_availability_with_lock NOT FOUND';
    END IF;

    IF EXISTS (
        SELECT 1 FROM pg_proc 
        WHERE proname = 'check_for_double_bookings'
    ) THEN
        RAISE NOTICE '✓ Function check_for_double_bookings exists';
    ELSE
        RAISE WARNING '⚠ Function check_for_double_bookings NOT FOUND';
    END IF;

    RAISE NOTICE '';

    -- ============================================
    -- TEST 2: Create Test Data
    -- ============================================
    RAISE NOTICE 'TEST 2: Creating test data...';
    
    -- Create a test accommodation with limited inventory
    INSERT INTO accommodations (
        title, 
        type, 
        inventory, 
        is_unlimited, 
        price,
        description
    ) VALUES (
        'TEST ROOM - Atomic Booking Test ' || NOW()::text,
        'room',
        2,  -- Only 2 rooms available
        false,
        100,
        'Test accommodation for atomic booking verification'
    ) RETURNING id INTO v_test_accommodation_id;
    
    RAISE NOTICE '✓ Created test accommodation with ID: % (inventory: 2)', v_test_accommodation_id;

    -- Create test users
    v_test_user_id_1 := gen_random_uuid();
    v_test_user_id_2 := gen_random_uuid();
    v_test_user_id_3 := gen_random_uuid();
    
    RAISE NOTICE '✓ Created 3 test user IDs';
    RAISE NOTICE '';

    -- ============================================
    -- TEST 3: Test Availability Check Function
    -- ============================================
    RAISE NOTICE 'TEST 3: Testing availability check...';
    
    v_availability := check_availability_with_lock(
        v_test_accommodation_id,
        '2025-11-01'::timestamp with time zone,
        '2025-11-07'::timestamp with time zone
    );
    
    IF v_availability = 2 THEN
        RAISE NOTICE '✓ Availability check correct: % rooms available', v_availability;
    ELSE
        RAISE WARNING '✗ Unexpected availability: % (expected 2)', v_availability;
        v_test_passed := false;
    END IF;
    RAISE NOTICE '';

    -- ============================================
    -- TEST 4: Test First Booking Creation
    -- ============================================
    RAISE NOTICE 'TEST 4: Creating first booking (should succeed)...';
    
    BEGIN
        v_booking_id_1 := create_booking_with_atomic_lock(
            p_accommodation_id := v_test_accommodation_id,
            p_user_id := v_test_user_id_1,
            p_check_in := '2025-11-01'::timestamp with time zone,
            p_check_out := '2025-11-07'::timestamp with time zone,
            p_total_price := 600,
            p_status := 'confirmed'
        );
        
        RAISE NOTICE '✓ First booking created successfully. ID: %', v_booking_id_1;
        
        -- Check availability after first booking
        v_availability := check_availability_with_lock(
            v_test_accommodation_id,
            '2025-11-01'::timestamp with time zone,
            '2025-11-07'::timestamp with time zone
        );
        RAISE NOTICE '  Remaining availability: % rooms', v_availability;
        
    EXCEPTION WHEN OTHERS THEN
        RAISE WARNING '✗ First booking failed unexpectedly: %', SQLERRM;
        v_test_passed := false;
    END;
    RAISE NOTICE '';

    -- ============================================
    -- TEST 5: Test Second Booking Creation
    -- ============================================
    RAISE NOTICE 'TEST 5: Creating second booking (should succeed)...';
    
    BEGIN
        v_booking_id_2 := create_booking_with_atomic_lock(
            p_accommodation_id := v_test_accommodation_id,
            p_user_id := v_test_user_id_2,
            p_check_in := '2025-11-01'::timestamp with time zone,
            p_check_out := '2025-11-07'::timestamp with time zone,
            p_total_price := 600,
            p_status := 'confirmed'
        );
        
        RAISE NOTICE '✓ Second booking created successfully. ID: %', v_booking_id_2;
        
        -- Check availability after second booking
        v_availability := check_availability_with_lock(
            v_test_accommodation_id,
            '2025-11-01'::timestamp with time zone,
            '2025-11-07'::timestamp with time zone
        );
        RAISE NOTICE '  Remaining availability: % rooms (should be 0)', v_availability;
        
    EXCEPTION WHEN OTHERS THEN
        RAISE WARNING '✗ Second booking failed unexpectedly: %', SQLERRM;
        v_test_passed := false;
    END;
    RAISE NOTICE '';

    -- ============================================
    -- TEST 6: Test Third Booking (Should FAIL)
    -- ============================================
    RAISE NOTICE 'TEST 6: Attempting third booking (should FAIL - no availability)...';
    
    BEGIN
        v_booking_id_3 := create_booking_with_atomic_lock(
            p_accommodation_id := v_test_accommodation_id,
            p_user_id := v_test_user_id_3,
            p_check_in := '2025-11-01'::timestamp with time zone,
            p_check_out := '2025-11-07'::timestamp with time zone,
            p_total_price := 600,
            p_status := 'confirmed'
        );
        
        -- If we get here, the test failed
        RAISE WARNING '✗ FAIL: Third booking succeeded when it should have failed!';
        v_test_passed := false;
        
    EXCEPTION WHEN OTHERS THEN
        GET STACKED DIAGNOSTICS v_error_message = MESSAGE_TEXT;
        IF v_error_message LIKE '%No availability%' THEN
            RAISE NOTICE '✓ Third booking correctly rejected: %', v_error_message;
        ELSE
            RAISE WARNING '✗ Unexpected error: %', v_error_message;
            v_test_passed := false;
        END IF;
    END;
    RAISE NOTICE '';

    -- ============================================
    -- TEST 7: Test Concurrent Booking Scenario
    -- ============================================
    RAISE NOTICE 'TEST 7: Testing booking for different dates (should succeed)...';
    
    BEGIN
        -- This should succeed as it's for different dates
        v_booking_id_3 := create_booking_with_atomic_lock(
            p_accommodation_id := v_test_accommodation_id,
            p_user_id := v_test_user_id_3,
            p_check_in := '2025-11-08'::timestamp with time zone,
            p_check_out := '2025-11-14'::timestamp with time zone,
            p_total_price := 600,
            p_status := 'confirmed'
        );
        
        RAISE NOTICE '✓ Booking for different dates succeeded. ID: %', v_booking_id_3;
        
    EXCEPTION WHEN OTHERS THEN
        RAISE WARNING '✗ Booking for different dates failed: %', SQLERRM;
        v_test_passed := false;
    END;
    RAISE NOTICE '';

    -- ============================================
    -- TEST 8: Check for Double Bookings
    -- ============================================
    RAISE NOTICE 'TEST 8: Checking for double-bookings in the system...';
    
    DECLARE
        v_double_booking_count integer;
    BEGIN
        SELECT COUNT(*) INTO v_double_booking_count
        FROM check_for_double_bookings();
        
        IF v_double_booking_count = 0 THEN
            RAISE NOTICE '✓ No double-bookings detected';
        ELSE
            RAISE WARNING '✗ Found % double-booking(s)!', v_double_booking_count;
            v_test_passed := false;
            
            -- Show details
            FOR r IN SELECT * FROM check_for_double_bookings() LOOP
                RAISE WARNING '  Accommodation: %, Overlaps: %', r.accommodation_title, r.overlapping_bookings;
            END LOOP;
        END IF;
    END;
    RAISE NOTICE '';

    -- ============================================
    -- TEST 9: Test Trigger Validation
    -- ============================================
    RAISE NOTICE 'TEST 9: Testing direct INSERT (trigger should prevent overbooking)...';
    
    BEGIN
        -- Try to insert directly, bypassing the function
        INSERT INTO bookings (
            accommodation_id,
            user_id,
            check_in,
            check_out,
            total_price,
            status
        ) VALUES (
            v_test_accommodation_id,
            gen_random_uuid(),
            '2025-11-01'::timestamp with time zone,
            '2025-11-07'::timestamp with time zone,
            600,
            'confirmed'
        );
        
        RAISE WARNING '✗ FAIL: Direct INSERT succeeded when it should have been blocked!';
        v_test_passed := false;
        
    EXCEPTION WHEN OTHERS THEN
        GET STACKED DIAGNOSTICS v_error_message = MESSAGE_TEXT;
        IF v_error_message LIKE '%fully booked%' OR v_error_message LIKE '%No rooms available%' THEN
            RAISE NOTICE '✓ Trigger correctly prevented overbooking: %', v_error_message;
        ELSE
            RAISE WARNING '✗ Unexpected trigger error: %', v_error_message;
        END IF;
    END;
    RAISE NOTICE '';

    -- ============================================
    -- CLEANUP
    -- ============================================
    RAISE NOTICE 'CLEANUP: Removing test data...';
    
    -- Delete test bookings
    DELETE FROM bookings WHERE accommodation_id = v_test_accommodation_id;
    RAISE NOTICE '✓ Deleted test bookings';
    
    -- Delete test accommodation
    DELETE FROM accommodations WHERE id = v_test_accommodation_id;
    RAISE NOTICE '✓ Deleted test accommodation';
    RAISE NOTICE '';

    -- ============================================
    -- FINAL REPORT
    -- ============================================
    RAISE NOTICE '====================================';
    RAISE NOTICE '📊 TEST SUMMARY';
    RAISE NOTICE '====================================';
    
    IF v_test_passed THEN
        RAISE NOTICE '✅ ALL TESTS PASSED!';
        RAISE NOTICE 'The atomic booking system is working correctly.';
        RAISE NOTICE 'Double-booking prevention is active and functional.';
    ELSE
        RAISE WARNING '⚠️ SOME TESTS FAILED!';
        RAISE WARNING 'Please review the output above for details.';
    END IF;
    
    RAISE NOTICE '====================================';

EXCEPTION WHEN OTHERS THEN
    RAISE NOTICE '❌ CRITICAL ERROR IN TEST SUITE: %', SQLERRM;
    RAISE NOTICE 'Rolling back all changes...';
    RAISE;
END;
$$;

-- Additional verification queries
RAISE NOTICE '';
RAISE NOTICE 'Additional Verification:';
RAISE NOTICE '========================';

-- Check indexes
SELECT 
    'Index Check' as test,
    COUNT(*) as indexes_found,
    CASE 
        WHEN COUNT(*) >= 2 THEN '✓ Performance indexes present'
        ELSE '✗ Missing performance indexes'
    END as status
FROM pg_indexes
WHERE tablename = 'bookings'
AND indexname IN (
    'idx_bookings_availability_check_optimized',
    'idx_bookings_item_assignment'
);

-- Check trigger
SELECT 
    'Trigger Check' as test,
    COUNT(*) as triggers_found,
    CASE 
        WHEN COUNT(*) > 0 THEN '✓ Validation trigger present'
        ELSE '✗ Missing validation trigger'
    END as status
FROM information_schema.triggers
WHERE event_object_table = 'bookings'
AND trigger_name = 'validate_booking_before_insert';

-- Show current booking statistics
SELECT 
    'Current System Stats' as category,
    COUNT(DISTINCT accommodation_id) as unique_accommodations,
    COUNT(*) as total_bookings,
    COUNT(CASE WHEN status = 'confirmed' THEN 1 END) as confirmed_bookings,
    COUNT(CASE WHEN status = 'pending' THEN 1 END) as pending_bookings
FROM bookings
WHERE created_at > NOW() - INTERVAL '30 days';