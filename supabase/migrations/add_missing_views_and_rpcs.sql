-- Missing Views and RPC Functions for Castle Booking App
-- Run this in Supabase SQL Editor after the functions

-- ============================================
-- VIEWS
-- ============================================

-- Application details view (combines applications with user info)
CREATE OR REPLACE VIEW public.application_details AS
SELECT 
    a.id,
    a.user_id,
    a.status,
    a.submitted_at,
    a.reviewed_at,
    a.reviewed_by,
    a.reviewer_notes,
    a.data,
    a.created_at,
    a.updated_at,
    p.email,
    p.first_name,
    p.last_name,
    p.phone,
    p.user_status,
    COALESCE(a.data->>'full_name', CONCAT(p.first_name, ' ', p.last_name)) AS full_name,
    a.data->>'arrival_date' AS arrival_date,
    a.data->>'departure_date' AS departure_date,
    a.data->>'accommodation_preference' AS accommodation_preference,
    a.data->>'special_requests' AS special_requests,
    a.data->>'linkedin_url' AS linkedin_url,
    a.data->>'twitter_url' AS twitter_url,
    a.data->>'website_url' AS website_url,
    a.data->>'emergency_contact' AS emergency_contact,
    a.data->>'dietary_restrictions' AS dietary_restrictions,
    a.data->>'admin_verdict' AS admin_verdict,
    COALESCE((a.data->>'tracking_field')::boolean, false) AS tracking_field,
    COALESCE((a.data->>'send_booking_reminder')::boolean, false) AS send_booking_reminder
FROM public.applications a
LEFT JOIN public.profiles p ON a.user_id = p.id
ORDER BY a.submitted_at DESC;

-- Whitelist user details view
CREATE OR REPLACE VIEW public.whitelist_user_details AS
SELECT 
    p.id,
    p.email,
    p.first_name,
    p.last_name,
    p.phone,
    p.user_status,
    p.created_at,
    p.updated_at,
    p.is_admin,
    a.id AS application_id,
    a.status AS application_status,
    a.submitted_at,
    a.data
FROM public.profiles p
LEFT JOIN public.applications a ON p.id = a.user_id
WHERE p.user_status = 'approved'
ORDER BY p.created_at DESC;

-- Bookings with user details view
CREATE OR REPLACE VIEW public.bookings_with_details AS
SELECT 
    b.*,
    p.email,
    p.first_name,
    p.last_name,
    p.phone,
    ac.title AS accommodation_title,
    ac.type AS accommodation_type,
    ac.base_price AS accommodation_base_price,
    ai.name AS item_name,
    ai.type AS item_type,
    ai.zone AS item_zone
FROM public.bookings b
LEFT JOIN public.profiles p ON b.user_id = p.id
LEFT JOIN public.accommodations ac ON b.accommodation_id = ac.id
LEFT JOIN public.accommodation_items ai ON b.accommodation_item_id = ai.id
ORDER BY b.check_in DESC;

-- ============================================
-- RPC FUNCTIONS
-- ============================================

-- Get user app entry status v2
CREATE OR REPLACE FUNCTION public.get_user_app_entry_status_v2(p_user_id uuid DEFAULT NULL)
RETURNS jsonb AS $$
DECLARE
    v_user_id uuid;
    v_result jsonb;
BEGIN
    v_user_id := COALESCE(p_user_id, auth.uid());
    
    IF v_user_id IS NULL THEN
        RETURN jsonb_build_object(
            'has_application', false,
            'application_status', null,
            'user_status', 'pending',
            'is_admin', false
        );
    END IF;
    
    SELECT jsonb_build_object(
        'has_application', EXISTS (SELECT 1 FROM public.applications WHERE user_id = v_user_id),
        'application_status', (SELECT status FROM public.applications WHERE user_id = v_user_id LIMIT 1),
        'user_status', COALESCE((SELECT user_status FROM public.profiles WHERE id = v_user_id), 'pending'),
        'is_admin', COALESCE((SELECT is_admin FROM public.profiles WHERE id = v_user_id), false)
    ) INTO v_result;
    
    RETURN v_result;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- Get user ID by email
CREATE OR REPLACE FUNCTION public.get_user_id_by_email(user_email text)
RETURNS uuid AS $$
DECLARE
    v_user_id uuid;
BEGIN
    -- Check if user is admin
    IF NOT public.is_admin() THEN
        RAISE EXCEPTION 'Only admins can look up users by email';
    END IF;
    
    SELECT id INTO v_user_id
    FROM auth.users
    WHERE email = user_email;
    
    RETURN v_user_id;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- Get accommodation availability
CREATE OR REPLACE FUNCTION public.get_accommodation_availability(
    p_accommodation_id uuid,
    p_start_date date,
    p_end_date date
)
RETURNS TABLE(
    date date,
    available_count integer,
    total_count integer,
    is_available boolean
) AS $$
BEGIN
    RETURN QUERY
    WITH date_series AS (
        SELECT generate_series(p_start_date, p_end_date, '1 day'::interval)::date AS date
    ),
    accommodation_info AS (
        SELECT 
            id,
            COALESCE(inventory, 1) AS total_inventory
        FROM public.accommodations
        WHERE id = p_accommodation_id
    ),
    bookings_per_date AS (
        SELECT 
            d::date AS date,
            COUNT(*) AS booked_count
        FROM public.bookings b,
        LATERAL generate_series(b.check_in, b.check_out - interval '1 day', '1 day'::interval) d
        WHERE b.accommodation_id = p_accommodation_id
        AND b.status IN ('confirmed', 'hold')
        AND d::date >= p_start_date
        AND d::date <= p_end_date
        GROUP BY d::date
    )
    SELECT 
        ds.date,
        (ai.total_inventory - COALESCE(bpd.booked_count, 0))::integer AS available_count,
        ai.total_inventory::integer AS total_count,
        (ai.total_inventory - COALESCE(bpd.booked_count, 0)) > 0 AS is_available
    FROM date_series ds
    CROSS JOIN accommodation_info ai
    LEFT JOIN bookings_per_date bpd ON ds.date = bpd.date
    ORDER BY ds.date;
END;
$$ LANGUAGE plpgsql;

-- Update application tracking field
CREATE OR REPLACE FUNCTION public.update_application_tracking_field(
    p_application_id uuid,
    p_value boolean
)
RETURNS boolean AS $$
BEGIN
    -- Check if user is admin
    IF NOT public.is_admin() THEN
        RAISE EXCEPTION 'Only admins can update tracking fields';
    END IF;
    
    UPDATE public.applications
    SET data = jsonb_set(data, '{tracking_field}', to_jsonb(p_value))
    WHERE id = p_application_id;
    
    RETURN true;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- Toggle booking reminder for user
CREATE OR REPLACE FUNCTION public.toggle_booking_reminder_for_user(
    p_application_id uuid
)
RETURNS boolean AS $$
DECLARE
    v_current_value boolean;
BEGIN
    -- Check if user is admin
    IF NOT public.is_admin() THEN
        RAISE EXCEPTION 'Only admins can toggle booking reminders';
    END IF;
    
    -- Get current value
    SELECT COALESCE((data->>'send_booking_reminder')::boolean, false) INTO v_current_value
    FROM public.applications
    WHERE id = p_application_id;
    
    -- Toggle it
    UPDATE public.applications
    SET data = jsonb_set(data, '{send_booking_reminder}', to_jsonb(NOT v_current_value))
    WHERE id = p_application_id;
    
    RETURN true;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- Toggle application tracking field
CREATE OR REPLACE FUNCTION public.toggle_application_tracking_field(
    p_application_id uuid
)
RETURNS boolean AS $$
DECLARE
    v_current_value boolean;
BEGIN
    -- Check if user is admin
    IF NOT public.is_admin() THEN
        RAISE EXCEPTION 'Only admins can toggle tracking fields';
    END IF;
    
    -- Get current value
    SELECT COALESCE((data->>'tracking_field')::boolean, false) INTO v_current_value
    FROM public.applications
    WHERE id = p_application_id;
    
    -- Toggle it
    UPDATE public.applications
    SET data = jsonb_set(data, '{tracking_field}', to_jsonb(NOT v_current_value))
    WHERE id = p_application_id;
    
    RETURN true;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- Update admin verdict
CREATE OR REPLACE FUNCTION public.update_admin_verdict(
    p_application_id uuid,
    p_verdict text
)
RETURNS boolean AS $$
BEGIN
    -- Check if user is admin
    IF NOT public.is_admin() THEN
        RAISE EXCEPTION 'Only admins can update verdicts';
    END IF;
    
    UPDATE public.applications
    SET data = jsonb_set(data, '{admin_verdict}', to_jsonb(p_verdict))
    WHERE id = p_application_id;
    
    RETURN true;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- Debug DB info (for admins only)
CREATE OR REPLACE FUNCTION public.debug_db_info()
RETURNS jsonb AS $$
DECLARE
    v_result jsonb;
BEGIN
    -- Check if user is admin
    IF NOT public.is_admin() THEN
        RAISE EXCEPTION 'Only admins can access debug info';
    END IF;
    
    SELECT jsonb_build_object(
        'total_users', (SELECT COUNT(*) FROM auth.users),
        'total_profiles', (SELECT COUNT(*) FROM public.profiles),
        'total_applications', (SELECT COUNT(*) FROM public.applications),
        'total_bookings', (SELECT COUNT(*) FROM public.bookings),
        'approved_users', (SELECT COUNT(*) FROM public.profiles WHERE user_status = 'approved'),
        'pending_applications', (SELECT COUNT(*) FROM public.applications WHERE status = 'pending')
    ) INTO v_result;
    
    RETURN v_result;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- Create confirmed booking (for testing)
CREATE OR REPLACE FUNCTION public.create_confirmed_booking(
    p_user_email text,
    p_accommodation_id uuid,
    p_check_in date,
    p_check_out date,
    p_total_price numeric
)
RETURNS uuid AS $$
DECLARE
    v_booking_id uuid;
    v_user_id uuid;
BEGIN
    -- Check if user is admin
    IF NOT public.is_admin() THEN
        RAISE EXCEPTION 'Only admins can create confirmed bookings';
    END IF;
    
    -- Get user ID
    SELECT id INTO v_user_id
    FROM auth.users
    WHERE email = p_user_email;
    
    IF v_user_id IS NULL THEN
        RAISE EXCEPTION 'User not found';
    END IF;
    
    -- Create booking
    INSERT INTO public.bookings (
        user_id,
        accommodation_id,
        check_in,
        check_out,
        total_price,
        status
    ) VALUES (
        v_user_id,
        p_accommodation_id,
        p_check_in,
        p_check_out,
        p_total_price,
        'confirmed'
    ) RETURNING id INTO v_booking_id;
    
    RETURN v_booking_id;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- Has housekeeping access
CREATE OR REPLACE FUNCTION public.has_housekeeping_access()
RETURNS boolean AS $$
BEGIN
    -- For now, only admins have housekeeping access
    -- You can modify this to check for a specific housekeeping role
    RETURN public.is_admin();
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- Admin add credits
CREATE OR REPLACE FUNCTION public.admin_add_credits(
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
    SET total_credits = COALESCE(total_credits, 0) + p_amount
    WHERE id = p_user_id;
    
    -- Record transaction
    INSERT INTO public.credit_transactions (user_id, amount, type, description)
    VALUES (p_user_id, p_amount, 'added', COALESCE(p_description, 'Admin added credits'));
    
    RETURN true;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- Admin remove credits
CREATE OR REPLACE FUNCTION public.admin_remove_credits(
    p_user_id uuid,
    p_amount numeric,
    p_description text DEFAULT NULL
)
RETURNS boolean AS $$
BEGIN
    -- Check if user is admin
    IF NOT public.is_admin() THEN
        RAISE EXCEPTION 'Only admins can remove credits';
    END IF;
    
    -- Update user credits
    UPDATE public.profiles
    SET total_credits = GREATEST(COALESCE(total_credits, 0) - p_amount, 0)
    WHERE id = p_user_id;
    
    -- Record transaction
    INSERT INTO public.credit_transactions (user_id, amount, type, description)
    VALUES (p_user_id, -p_amount, 'removed', COALESCE(p_description, 'Admin removed credits'));
    
    RETURN true;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- ============================================
-- GRANT PERMISSIONS
-- ============================================

-- Grant permissions for views
GRANT SELECT ON public.application_details TO authenticated;
GRANT SELECT ON public.whitelist_user_details TO authenticated;
GRANT SELECT ON public.bookings_with_details TO authenticated;

-- Grant permissions for new RPC functions
GRANT EXECUTE ON FUNCTION public.get_user_app_entry_status_v2(uuid) TO authenticated;
GRANT EXECUTE ON FUNCTION public.get_user_id_by_email(text) TO authenticated;
GRANT EXECUTE ON FUNCTION public.get_accommodation_availability(uuid, date, date) TO authenticated;
GRANT EXECUTE ON FUNCTION public.update_application_tracking_field(uuid, boolean) TO authenticated;
GRANT EXECUTE ON FUNCTION public.toggle_booking_reminder_for_user(uuid) TO authenticated;
GRANT EXECUTE ON FUNCTION public.toggle_application_tracking_field(uuid) TO authenticated;
GRANT EXECUTE ON FUNCTION public.update_admin_verdict(uuid, text) TO authenticated;
GRANT EXECUTE ON FUNCTION public.debug_db_info() TO authenticated;
GRANT EXECUTE ON FUNCTION public.create_confirmed_booking(text, uuid, date, date, numeric) TO authenticated;
GRANT EXECUTE ON FUNCTION public.has_housekeeping_access() TO authenticated;
GRANT EXECUTE ON FUNCTION public.admin_add_credits(uuid, numeric, text) TO authenticated;
GRANT EXECUTE ON FUNCTION public.admin_remove_credits(uuid, numeric, text) TO authenticated;

-- ============================================
-- DONE! All missing views and RPCs added.
-- ============================================