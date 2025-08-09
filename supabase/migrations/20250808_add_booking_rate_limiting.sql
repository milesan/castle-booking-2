-- Add rate limiting to prevent malicious users from blocking bookings
-- Limits users to 2 pending bookings at a time and 5 booking attempts per hour

BEGIN;

-- 1. Create a function to check if a user has too many pending bookings
CREATE OR REPLACE FUNCTION check_pending_booking_limit()
RETURNS TRIGGER
LANGUAGE plpgsql
AS $$
DECLARE
    pending_count INTEGER;
    recent_attempts INTEGER;
BEGIN
    -- Only check for new pending bookings
    IF NEW.status = 'pending' THEN
        -- Count existing pending bookings for this user
        SELECT COUNT(*)
        INTO pending_count
        FROM bookings
        WHERE user_id = NEW.user_id
        AND status = 'pending'
        AND created_at > NOW() - INTERVAL '10 minutes';
        
        -- Limit to 2 pending bookings at a time
        IF pending_count >= 2 THEN
            RAISE EXCEPTION 'You already have pending bookings. Please complete or cancel them before making new reservations.';
        END IF;
        
        -- Count recent booking attempts (including cancelled ones) to prevent abuse
        SELECT COUNT(*)
        INTO recent_attempts
        FROM bookings
        WHERE user_id = NEW.user_id
        AND created_at > NOW() - INTERVAL '1 hour';
        
        -- Limit to 5 booking attempts per hour
        IF recent_attempts >= 5 THEN
            RAISE EXCEPTION 'Too many booking attempts. Please wait before trying again.';
        END IF;
    END IF;
    
    RETURN NEW;
END;
$$;

-- 2. Create trigger for rate limiting
DROP TRIGGER IF EXISTS booking_rate_limit_check ON bookings;
CREATE TRIGGER booking_rate_limit_check
    BEFORE INSERT ON bookings
    FOR EACH ROW
    EXECUTE FUNCTION check_pending_booking_limit();

-- 3. Create an index to make rate limit checks efficient
CREATE INDEX IF NOT EXISTS idx_bookings_user_pending 
ON bookings(user_id, status, created_at)
WHERE status = 'pending';

-- 4. Add a function to cleanup abandoned bookings more aggressively for repeat offenders
CREATE OR REPLACE FUNCTION cleanup_suspicious_bookings()
RETURNS void
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
BEGIN
    -- Find users with multiple cancelled/abandoned bookings
    WITH suspicious_users AS (
        SELECT user_id
        FROM bookings
        WHERE status = 'cancelled'
        AND created_at > NOW() - INTERVAL '24 hours'
        GROUP BY user_id
        HAVING COUNT(*) >= 3
    )
    -- Cancel their pending bookings more quickly (after 5 minutes instead of 10)
    UPDATE bookings
    SET 
        status = 'cancelled',
        updated_at = NOW(),
        notes = COALESCE(notes, '{}'::jsonb) || jsonb_build_object(
            'auto_cancelled_at', NOW(), 
            'reason', 'Suspicious activity - early timeout'
        )
    WHERE 
        status = 'pending'
        AND user_id IN (SELECT user_id FROM suspicious_users)
        AND created_at < NOW() - INTERVAL '5 minutes';
END;
$$;

-- 5. Add a comment explaining the rate limiting
COMMENT ON FUNCTION check_pending_booking_limit IS 
'Rate limiting for bookings:
- Max 2 pending bookings per user at any time
- Max 5 booking attempts per hour per user
- Prevents malicious users from blocking inventory';

COMMIT;