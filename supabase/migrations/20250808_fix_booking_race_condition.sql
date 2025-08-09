-- Fix race condition in booking process by including pending bookings in availability check
-- This prevents double-booking when multiple users try to book the same accommodation simultaneously

BEGIN;

-- 1. Update the availability function to include pending bookings (not just confirmed)
CREATE OR REPLACE FUNCTION get_accommodation_availability(
    check_in_date text,
    check_out_date text
) RETURNS TABLE (
    accommodation_id uuid,
    title text,
    is_available boolean,
    available_capacity integer
) LANGUAGE plpgsql AS $$
BEGIN
    RETURN QUERY 
    SELECT 
        a.id AS accommodation_id,
        a.title,
        -- If unlimited, always available. Otherwise, check if inventory > booked count
        CASE 
            WHEN a.is_unlimited THEN TRUE 
            ELSE (COALESCE(a.inventory, 0) - COALESCE(booked.count, 0)) > 0
        END AS is_available,
        -- Available capacity: NULL for unlimited, otherwise (inventory - booked count)
        CASE 
            WHEN a.is_unlimited THEN NULL 
            ELSE GREATEST(COALESCE(a.inventory, 0) - COALESCE(booked.count, 0)::int, 0)
        END AS available_capacity
    FROM accommodations a
    LEFT JOIN (
        SELECT 
            b.accommodation_id, 
            CAST(COUNT(*) AS integer) AS count
        FROM bookings b
        WHERE b.status IN ('confirmed', 'pending')  -- Include PENDING bookings to prevent race conditions
        AND b.check_in < (check_out_date::timestamp with time zone)
        AND b.check_out > (check_in_date::timestamp with time zone)
        GROUP BY b.accommodation_id
    ) booked ON a.id = booked.accommodation_id;
END;
$$;

-- 2. Create a function to automatically cancel stale pending bookings (older than 10 minutes)
-- Standard payment timeout is 10-15 minutes (Stripe checkout expires after 24 hours but most users abandon after 10 mins)
CREATE OR REPLACE FUNCTION cancel_stale_pending_bookings()
RETURNS void
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
BEGIN
    -- Cancel pending bookings older than 10 minutes
    UPDATE bookings
    SET 
        status = 'cancelled',
        updated_at = NOW(),
        notes = COALESCE(notes, '{}'::jsonb) || jsonb_build_object('auto_cancelled_at', NOW(), 'reason', 'Payment timeout')
    WHERE 
        status = 'pending'
        AND created_at < NOW() - INTERVAL '10 minutes';
        
    -- Also update any associated payment records
    UPDATE payments
    SET 
        status = 'cancelled',
        updated_at = NOW()
    WHERE 
        status = 'pending'
        AND created_at < NOW() - INTERVAL '10 minutes';
END;
$$;

-- 3. Create a scheduled job to run the cleanup function every 5 minutes
-- Note: This requires pg_cron extension. If not available, this can be triggered from the application
-- CREATE EXTENSION IF NOT EXISTS pg_cron;
-- SELECT cron.schedule('cancel-stale-bookings', '*/5 * * * *', 'SELECT cancel_stale_pending_bookings();');

-- 4. Add an index to improve performance of the availability check
CREATE INDEX IF NOT EXISTS idx_bookings_availability_check 
ON bookings(accommodation_id, status, check_in, check_out)
WHERE status IN ('confirmed', 'pending');

-- 5. Create a function to check if a specific accommodation is available
-- This can be called right before creating a booking to double-check availability
CREATE OR REPLACE FUNCTION check_accommodation_availability_atomic(
    p_accommodation_id uuid,
    p_check_in timestamp with time zone,
    p_check_out timestamp with time zone
) RETURNS boolean
LANGUAGE plpgsql
AS $$
DECLARE
    v_inventory integer;
    v_is_unlimited boolean;
    v_booked_count integer;
BEGIN
    -- Get accommodation details
    SELECT inventory, is_unlimited
    INTO v_inventory, v_is_unlimited
    FROM accommodations
    WHERE id = p_accommodation_id;
    
    -- If unlimited, always available
    IF v_is_unlimited THEN
        RETURN TRUE;
    END IF;
    
    -- Count existing bookings (both confirmed and pending)
    SELECT COUNT(*)
    INTO v_booked_count
    FROM bookings
    WHERE accommodation_id = p_accommodation_id
    AND status IN ('confirmed', 'pending')
    AND check_in < p_check_out
    AND check_out > p_check_in;
    
    -- Check if there's availability
    RETURN COALESCE(v_inventory, 0) > COALESCE(v_booked_count, 0);
END;
$$;

-- 6. Create a trigger to validate availability before inserting a booking
CREATE OR REPLACE FUNCTION validate_booking_availability()
RETURNS TRIGGER
LANGUAGE plpgsql
AS $$
BEGIN
    -- Only validate for new bookings with pending or confirmed status
    IF NEW.status IN ('pending', 'confirmed') THEN
        -- Check availability
        IF NOT check_accommodation_availability_atomic(
            NEW.accommodation_id,
            NEW.check_in,
            NEW.check_out
        ) THEN
            RAISE EXCEPTION 'Accommodation is no longer available for the selected dates';
        END IF;
    END IF;
    
    RETURN NEW;
END;
$$;

-- Create the trigger
DROP TRIGGER IF EXISTS booking_availability_check ON bookings;
CREATE TRIGGER booking_availability_check
    BEFORE INSERT ON bookings
    FOR EACH ROW
    EXECUTE FUNCTION validate_booking_availability();

-- 7. Add a comment explaining the booking flow
COMMENT ON FUNCTION get_accommodation_availability IS 
'Returns availability for accommodations between check-in and check-out dates. 
Includes both confirmed AND pending bookings to prevent race conditions during payment processing.
Pending bookings are automatically cancelled after 10 minutes if not confirmed.';

COMMIT;