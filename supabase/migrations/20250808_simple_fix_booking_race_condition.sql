-- Simple fix: Include pending bookings in availability check to prevent double-booking
-- Pending bookings auto-expire after 10 minutes

BEGIN;

-- Update the availability function to include pending bookings
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
        CASE 
            WHEN a.is_unlimited THEN TRUE 
            ELSE (COALESCE(a.inventory, 0) - COALESCE(booked.count, 0)) > 0
        END AS is_available,
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
        WHERE b.status IN ('confirmed', 'pending')  -- COUNT BOTH
        AND b.check_in < (check_out_date::timestamp with time zone)
        AND b.check_out > (check_in_date::timestamp with time zone)
        GROUP BY b.accommodation_id
    ) booked ON a.id = booked.accommodation_id;
END;
$$;

-- Simple cleanup function for old pending bookings (5 minutes timeout)
CREATE OR REPLACE FUNCTION cancel_old_pending_bookings()
RETURNS void
LANGUAGE plpgsql
AS $$
BEGIN
    UPDATE bookings
    SET status = 'cancelled',
        notes = COALESCE(notes, '{}'::jsonb) || jsonb_build_object(
            'auto_cancelled_at', NOW(), 
            'reason', 'Payment timeout after 5 minutes'
        )
    WHERE status = 'pending'
    AND created_at < NOW() - INTERVAL '5 minutes';
END;
$$;

COMMIT;