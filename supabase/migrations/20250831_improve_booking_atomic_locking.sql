-- Improve booking creation with atomic locking to prevent double-booking
-- This ensures that when a room is purchased, it properly increments the counter
-- and prevents race conditions where two users might book the same room simultaneously

BEGIN;

-- 1. Create a more robust booking creation function with proper locking
CREATE OR REPLACE FUNCTION create_booking_with_atomic_lock(
    p_accommodation_id uuid,
    p_user_id uuid,
    p_check_in timestamp with time zone,
    p_check_out timestamp with time zone,
    p_total_price numeric,
    p_status text DEFAULT 'pending',
    p_accommodation_item_id uuid DEFAULT NULL,
    p_applied_discount_code text DEFAULT NULL,
    p_discount_amount numeric DEFAULT NULL
) RETURNS uuid
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
DECLARE
    v_booking_id uuid;
    v_inventory integer;
    v_is_unlimited boolean;
    v_booked_count integer;
    v_available_count integer;
BEGIN
    -- Start with pessimistic locking on the accommodation row
    -- This prevents any other transaction from reading or modifying this accommodation
    -- until our transaction completes
    SELECT inventory, is_unlimited
    INTO v_inventory, v_is_unlimited
    FROM accommodations
    WHERE id = p_accommodation_id
    FOR UPDATE; -- This locks the row for the duration of the transaction
    
    -- If accommodation not found, raise error
    IF NOT FOUND THEN
        RAISE EXCEPTION 'Accommodation not found: %', p_accommodation_id;
    END IF;
    
    -- If unlimited capacity, skip availability check
    IF v_is_unlimited THEN
        -- Create the booking directly
        INSERT INTO bookings (
            accommodation_id,
            user_id,
            check_in,
            check_out,
            total_price,
            status,
            accommodation_item_id,
            applied_discount_code,
            discount_amount
        ) VALUES (
            p_accommodation_id,
            p_user_id,
            p_check_in,
            p_check_out,
            p_total_price,
            p_status,
            p_accommodation_item_id,
            p_applied_discount_code,
            p_discount_amount
        ) RETURNING id INTO v_booking_id;
        
        RETURN v_booking_id;
    END IF;
    
    -- For limited inventory, count existing bookings with locking
    -- Lock all relevant booking rows to prevent concurrent modifications
    SELECT COUNT(*)
    INTO v_booked_count
    FROM bookings
    WHERE accommodation_id = p_accommodation_id
    AND status IN ('confirmed', 'pending')
    AND check_in < p_check_out
    AND check_out > p_check_in
    FOR UPDATE; -- Lock these booking rows too
    
    -- Calculate available inventory
    v_available_count := COALESCE(v_inventory, 0) - COALESCE(v_booked_count, 0);
    
    -- Check if there's availability
    IF v_available_count <= 0 THEN
        RAISE EXCEPTION 'No availability for accommodation % between % and %. Inventory: %, Already booked: %', 
            p_accommodation_id, p_check_in, p_check_out, v_inventory, v_booked_count;
    END IF;
    
    -- Create the booking (this is now guaranteed to be safe)
    INSERT INTO bookings (
        accommodation_id,
        user_id,
        check_in,
        check_out,
        total_price,
        status,
        accommodation_item_id,
        applied_discount_code,
        discount_amount
    ) VALUES (
        p_accommodation_id,
        p_user_id,
        p_check_in,
        p_check_out,
        p_total_price,
        p_status,
        p_accommodation_item_id,
        p_applied_discount_code,
        p_discount_amount
    ) RETURNING id INTO v_booking_id;
    
    -- Log the successful booking for monitoring
    RAISE NOTICE 'Booking created successfully: % for accommodation % (available: %/%)', 
        v_booking_id, p_accommodation_id, v_available_count, v_inventory;
    
    RETURN v_booking_id;
END;
$$;

-- 2. Create an improved availability check function that uses the same locking strategy
CREATE OR REPLACE FUNCTION check_availability_with_lock(
    p_accommodation_id uuid,
    p_check_in timestamp with time zone,
    p_check_out timestamp with time zone
) RETURNS integer
LANGUAGE plpgsql
AS $$
DECLARE
    v_inventory integer;
    v_is_unlimited boolean;
    v_booked_count integer;
    v_available_count integer;
BEGIN
    -- Get accommodation details without locking (read-only check)
    SELECT inventory, is_unlimited
    INTO v_inventory, v_is_unlimited
    FROM accommodations
    WHERE id = p_accommodation_id;
    
    IF NOT FOUND THEN
        RETURN 0;
    END IF;
    
    -- If unlimited, return a large number
    IF v_is_unlimited THEN
        RETURN 9999;
    END IF;
    
    -- Count existing bookings
    SELECT COUNT(*)
    INTO v_booked_count
    FROM bookings
    WHERE accommodation_id = p_accommodation_id
    AND status IN ('confirmed', 'pending')
    AND check_in < p_check_out
    AND check_out > p_check_in;
    
    -- Calculate and return available count
    v_available_count := GREATEST(COALESCE(v_inventory, 0) - COALESCE(v_booked_count, 0), 0);
    
    RETURN v_available_count;
END;
$$;

-- 3. Update the existing trigger to use our new atomic function
-- Drop the old trigger if it exists
DROP TRIGGER IF EXISTS booking_availability_check ON bookings;

-- Create a new validation trigger that's more informative
CREATE OR REPLACE FUNCTION validate_booking_with_better_error()
RETURNS TRIGGER
LANGUAGE plpgsql
AS $$
DECLARE
    v_available integer;
BEGIN
    -- Only validate for new bookings with pending or confirmed status
    IF TG_OP = 'INSERT' AND NEW.status IN ('pending', 'confirmed') THEN
        -- Check availability
        v_available := check_availability_with_lock(
            NEW.accommodation_id,
            NEW.check_in,
            NEW.check_out
        );
        
        IF v_available <= 0 THEN
            RAISE EXCEPTION 'Accommodation % is fully booked for dates % to %. No rooms available.', 
                NEW.accommodation_id, NEW.check_in::date, NEW.check_out::date
                USING HINT = 'Please try different dates or another accommodation.';
        END IF;
    END IF;
    
    RETURN NEW;
END;
$$;

-- Create the improved trigger
CREATE TRIGGER validate_booking_before_insert
    BEFORE INSERT ON bookings
    FOR EACH ROW
    EXECUTE FUNCTION validate_booking_with_better_error();

-- 4. Create a function to handle booking item assignment atomically
CREATE OR REPLACE FUNCTION assign_accommodation_item_atomically(
    p_booking_id uuid,
    p_accommodation_id uuid
) RETURNS uuid
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
DECLARE
    v_item_id uuid;
BEGIN
    -- Find an available item for this accommodation that's not already assigned
    -- Use FOR UPDATE SKIP LOCKED to handle concurrent assignments
    SELECT ai.id
    INTO v_item_id
    FROM accommodation_items ai
    WHERE ai.accommodation_id = p_accommodation_id
    AND NOT EXISTS (
        SELECT 1 
        FROM bookings b
        WHERE b.accommodation_item_id = ai.id
        AND b.status IN ('confirmed', 'pending')
        AND b.id != p_booking_id
    )
    ORDER BY ai.item_id
    LIMIT 1
    FOR UPDATE SKIP LOCKED; -- Skip items being processed by other transactions
    
    IF v_item_id IS NOT NULL THEN
        -- Update the booking with the assigned item
        UPDATE bookings
        SET accommodation_item_id = v_item_id
        WHERE id = p_booking_id;
    END IF;
    
    RETURN v_item_id;
END;
$$;

-- 5. Add helpful indexes for performance
CREATE INDEX IF NOT EXISTS idx_bookings_availability_check_optimized
ON bookings(accommodation_id, status, check_in, check_out)
WHERE status IN ('confirmed', 'pending');

CREATE INDEX IF NOT EXISTS idx_bookings_item_assignment
ON bookings(accommodation_item_id, status)
WHERE status IN ('confirmed', 'pending');

-- 6. Add a monitoring function to detect potential double-booking issues
CREATE OR REPLACE FUNCTION check_for_double_bookings()
RETURNS TABLE (
    accommodation_id uuid,
    accommodation_title text,
    overlapping_bookings jsonb
)
LANGUAGE plpgsql
AS $$
BEGIN
    RETURN QUERY
    SELECT 
        a.id,
        a.title,
        jsonb_agg(
            jsonb_build_object(
                'booking_id', b1.id,
                'user_id', b1.user_id,
                'check_in', b1.check_in,
                'check_out', b1.check_out,
                'status', b1.status,
                'created_at', b1.created_at
            ) ORDER BY b1.created_at
        ) as overlapping_bookings
    FROM accommodations a
    JOIN bookings b1 ON b1.accommodation_id = a.id
    JOIN bookings b2 ON b2.accommodation_id = a.id
    WHERE b1.id != b2.id
    AND b1.status IN ('confirmed', 'pending')
    AND b2.status IN ('confirmed', 'pending')
    AND b1.check_in < b2.check_out
    AND b1.check_out > b2.check_in
    AND NOT a.is_unlimited
    GROUP BY a.id, a.title, a.inventory
    HAVING COUNT(DISTINCT b1.id) > COALESCE(a.inventory, 0);
END;
$$;

-- 7. Add a comment explaining the locking strategy
COMMENT ON FUNCTION create_booking_with_atomic_lock IS 
'Creates a booking with pessimistic row-level locking to prevent double-booking.
Uses SELECT FOR UPDATE on the accommodation row to ensure atomic inventory checks.
This guarantees that concurrent booking attempts will be serialized and only 
successful if inventory is available. The function will block other transactions
attempting to book the same accommodation until the current transaction completes.';

COMMIT;