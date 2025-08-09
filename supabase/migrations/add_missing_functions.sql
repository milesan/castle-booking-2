-- Missing Functions for Castle Booking App
-- Run this in Supabase SQL Editor after the main schema

-- ============================================
-- ADMIN & USER FUNCTIONS
-- ============================================

-- Function to check if user is admin
CREATE OR REPLACE FUNCTION public.is_admin()
RETURNS boolean AS $$
BEGIN
    RETURN EXISTS (
        SELECT 1 FROM public.profiles
        WHERE id = auth.uid()
        AND is_admin = true
    );
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- Function to check if user is admin (with user_id parameter)
CREATE OR REPLACE FUNCTION public.is_admin(user_id uuid)
RETURNS boolean AS $$
BEGIN
    RETURN EXISTS (
        SELECT 1 FROM public.profiles
        WHERE id = user_id
        AND is_admin = true
    );
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- Function to get user status
CREATE OR REPLACE FUNCTION public.get_user_status()
RETURNS text AS $$
DECLARE
    v_status text;
BEGIN
    SELECT user_status::text INTO v_status
    FROM public.profiles
    WHERE id = auth.uid();
    
    RETURN COALESCE(v_status, 'pending');
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- ============================================
-- BOOKING FUNCTIONS
-- ============================================

-- Function to create a booking
CREATE OR REPLACE FUNCTION public.create_booking(
    p_accommodation_id uuid,
    p_check_in date,
    p_check_out date,
    p_total_price numeric,
    p_base_price numeric DEFAULT NULL,
    p_discount_amount numeric DEFAULT 0,
    p_credits_applied numeric DEFAULT 0,
    p_discount_code text DEFAULT NULL,
    p_notes text DEFAULT NULL
)
RETURNS uuid AS $$
DECLARE
    v_booking_id uuid;
    v_user_id uuid;
BEGIN
    -- Get current user
    v_user_id := auth.uid();
    
    IF v_user_id IS NULL THEN
        RAISE EXCEPTION 'User not authenticated';
    END IF;
    
    -- Check availability
    IF NOT public.check_availability(p_accommodation_id, p_check_in, p_check_out) THEN
        RAISE EXCEPTION 'Accommodation not available for selected dates';
    END IF;
    
    -- Create booking
    INSERT INTO public.bookings (
        user_id,
        accommodation_id,
        check_in,
        check_out,
        total_price,
        base_price,
        discount_amount,
        credits_applied,
        final_price,
        discount_code,
        notes,
        status
    ) VALUES (
        v_user_id,
        p_accommodation_id,
        p_check_in,
        p_check_out,
        p_total_price,
        COALESCE(p_base_price, p_total_price),
        p_discount_amount,
        p_credits_applied,
        p_total_price - p_discount_amount - p_credits_applied,
        p_discount_code,
        p_notes,
        'pending'
    ) RETURNING id INTO v_booking_id;
    
    RETURN v_booking_id;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- Function to cancel a booking
CREATE OR REPLACE FUNCTION public.cancel_booking(p_booking_id uuid)
RETURNS boolean AS $$
DECLARE
    v_user_id uuid;
    v_booking_user_id uuid;
BEGIN
    v_user_id := auth.uid();
    
    -- Get booking owner
    SELECT user_id INTO v_booking_user_id
    FROM public.bookings
    WHERE id = p_booking_id;
    
    -- Check if user owns the booking or is admin
    IF v_booking_user_id != v_user_id AND NOT public.is_admin() THEN
        RAISE EXCEPTION 'Unauthorized to cancel this booking';
    END IF;
    
    -- Update booking status
    UPDATE public.bookings
    SET status = 'cancelled',
        updated_at = now()
    WHERE id = p_booking_id;
    
    RETURN true;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- ============================================
-- AVAILABILITY FUNCTIONS
-- ============================================

-- Function to get availability for date range
CREATE OR REPLACE FUNCTION public.get_availability(
    p_accommodation_id uuid,
    p_start_date date,
    p_end_date date
)
RETURNS TABLE(
    date date,
    is_available boolean,
    price numeric
) AS $$
BEGIN
    RETURN QUERY
    WITH date_series AS (
        SELECT generate_series(p_start_date, p_end_date - interval '1 day', '1 day'::interval)::date AS date
    ),
    booked_dates AS (
        SELECT DISTINCT d::date AS date
        FROM public.bookings b,
        LATERAL generate_series(b.check_in, b.check_out - interval '1 day', '1 day'::interval) d
        WHERE b.accommodation_id = p_accommodation_id
        AND b.status IN ('confirmed', 'hold')
        AND d::date >= p_start_date
        AND d::date <= p_end_date
    ),
    accommodation_price AS (
        SELECT base_price
        FROM public.accommodations
        WHERE id = p_accommodation_id
    )
    SELECT 
        ds.date,
        bd.date IS NULL AS is_available,
        ap.base_price AS price
    FROM date_series ds
    CROSS JOIN accommodation_price ap
    LEFT JOIN booked_dates bd ON ds.date = bd.date
    ORDER BY ds.date;
END;
$$ LANGUAGE plpgsql;

-- ============================================
-- APPLICATION FUNCTIONS
-- ============================================

-- Function to submit application
CREATE OR REPLACE FUNCTION public.submit_application(
    p_data jsonb
)
RETURNS uuid AS $$
DECLARE
    v_application_id uuid;
    v_user_id uuid;
BEGIN
    v_user_id := auth.uid();
    
    IF v_user_id IS NULL THEN
        RAISE EXCEPTION 'User not authenticated';
    END IF;
    
    -- Check if user already has an application
    IF EXISTS (SELECT 1 FROM public.applications WHERE user_id = v_user_id) THEN
        -- Update existing application
        UPDATE public.applications
        SET data = p_data,
            updated_at = now()
        WHERE user_id = v_user_id
        RETURNING id INTO v_application_id;
    ELSE
        -- Create new application
        INSERT INTO public.applications (user_id, data, status)
        VALUES (v_user_id, p_data, 'pending')
        RETURNING id INTO v_application_id;
    END IF;
    
    RETURN v_application_id;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- Function to approve application
CREATE OR REPLACE FUNCTION public.approve_application(
    p_application_id uuid,
    p_notes text DEFAULT NULL
)
RETURNS boolean AS $$
DECLARE
    v_user_id uuid;
BEGIN
    -- Check if user is admin
    IF NOT public.is_admin() THEN
        RAISE EXCEPTION 'Only admins can approve applications';
    END IF;
    
    -- Get user_id from application
    SELECT user_id INTO v_user_id
    FROM public.applications
    WHERE id = p_application_id;
    
    -- Update application
    UPDATE public.applications
    SET status = 'approved',
        reviewed_at = now(),
        reviewed_by = auth.uid(),
        reviewer_notes = p_notes
    WHERE id = p_application_id;
    
    -- Update user profile
    UPDATE public.profiles
    SET user_status = 'approved'
    WHERE id = v_user_id;
    
    RETURN true;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- Function to reject application
CREATE OR REPLACE FUNCTION public.reject_application(
    p_application_id uuid,
    p_notes text DEFAULT NULL
)
RETURNS boolean AS $$
DECLARE
    v_user_id uuid;
BEGIN
    -- Check if user is admin
    IF NOT public.is_admin() THEN
        RAISE EXCEPTION 'Only admins can reject applications';
    END IF;
    
    -- Get user_id from application
    SELECT user_id INTO v_user_id
    FROM public.applications
    WHERE id = p_application_id;
    
    -- Update application
    UPDATE public.applications
    SET status = 'rejected',
        reviewed_at = now(),
        reviewed_by = auth.uid(),
        reviewer_notes = p_notes
    WHERE id = p_application_id;
    
    -- Update user profile
    UPDATE public.profiles
    SET user_status = 'rejected'
    WHERE id = v_user_id;
    
    RETURN true;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- ============================================
-- CREDIT FUNCTIONS
-- ============================================

-- Function to add credits to user
CREATE OR REPLACE FUNCTION public.add_credits(
    p_user_id uuid,
    p_amount numeric,
    p_description text DEFAULT NULL
)
RETURNS boolean AS $$
BEGIN
    -- Check if user is admin
    IF NOT public.is_admin() THEN
        RAISE EXCEPTION 'Only admins can add credits';
    END IF;
    
    -- Update user credits
    UPDATE public.profiles
    SET total_credits = total_credits + p_amount
    WHERE id = p_user_id;
    
    -- Record transaction
    INSERT INTO public.credit_transactions (user_id, amount, type, description)
    VALUES (p_user_id, p_amount, 'added', p_description);
    
    RETURN true;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- Function to use credits
CREATE OR REPLACE FUNCTION public.use_credits(
    p_booking_id uuid,
    p_amount numeric
)
RETURNS boolean AS $$
DECLARE
    v_user_id uuid;
    v_available_credits numeric;
BEGIN
    -- Get user from booking
    SELECT user_id INTO v_user_id
    FROM public.bookings
    WHERE id = p_booking_id;
    
    -- Check available credits
    SELECT total_credits - used_credits INTO v_available_credits
    FROM public.profiles
    WHERE id = v_user_id;
    
    IF v_available_credits < p_amount THEN
        RAISE EXCEPTION 'Insufficient credits';
    END IF;
    
    -- Update used credits
    UPDATE public.profiles
    SET used_credits = used_credits + p_amount
    WHERE id = v_user_id;
    
    -- Update booking
    UPDATE public.bookings
    SET credits_applied = p_amount,
        final_price = total_price - discount_amount - p_amount
    WHERE id = p_booking_id;
    
    -- Record transaction
    INSERT INTO public.credit_transactions (user_id, amount, type, description, booking_id)
    VALUES (v_user_id, p_amount, 'used', 'Applied to booking', p_booking_id);
    
    RETURN true;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- ============================================
-- STATISTICS FUNCTIONS
-- ============================================

-- Function to get booking stats
CREATE OR REPLACE FUNCTION public.get_booking_stats()
RETURNS jsonb AS $$
DECLARE
    v_stats jsonb;
BEGIN
    SELECT jsonb_build_object(
        'total_bookings', COUNT(*),
        'pending_bookings', COUNT(*) FILTER (WHERE status = 'pending'),
        'confirmed_bookings', COUNT(*) FILTER (WHERE status = 'confirmed'),
        'cancelled_bookings', COUNT(*) FILTER (WHERE status = 'cancelled'),
        'total_revenue', COALESCE(SUM(final_price), 0),
        'bookings_this_month', COUNT(*) FILTER (WHERE created_at >= date_trunc('month', now())),
        'revenue_this_month', COALESCE(SUM(final_price) FILTER (WHERE created_at >= date_trunc('month', now())), 0)
    ) INTO v_stats
    FROM public.bookings;
    
    RETURN v_stats;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- ============================================
-- GRANT PERMISSIONS
-- ============================================

GRANT EXECUTE ON FUNCTION public.is_admin() TO authenticated;
GRANT EXECUTE ON FUNCTION public.is_admin(uuid) TO authenticated;
GRANT EXECUTE ON FUNCTION public.get_user_status() TO authenticated;
GRANT EXECUTE ON FUNCTION public.create_booking(uuid, date, date, numeric, numeric, numeric, numeric, text, text) TO authenticated;
GRANT EXECUTE ON FUNCTION public.cancel_booking(uuid) TO authenticated;
GRANT EXECUTE ON FUNCTION public.check_availability(uuid, date, date) TO authenticated;
GRANT EXECUTE ON FUNCTION public.get_availability(uuid, date, date) TO authenticated;
GRANT EXECUTE ON FUNCTION public.submit_application(jsonb) TO authenticated;
GRANT EXECUTE ON FUNCTION public.approve_application(uuid, text) TO authenticated;
GRANT EXECUTE ON FUNCTION public.reject_application(uuid, text) TO authenticated;
GRANT EXECUTE ON FUNCTION public.add_credits(uuid, numeric, text) TO authenticated;
GRANT EXECUTE ON FUNCTION public.use_credits(uuid, numeric) TO authenticated;
GRANT EXECUTE ON FUNCTION public.get_booking_stats() TO authenticated;

-- ============================================
-- DONE! All missing functions added.
-- ============================================