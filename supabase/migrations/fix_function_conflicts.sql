-- Fix for function conflicts - DROP existing functions first
-- Run this BEFORE add_missing_views_and_rpcs.sql

-- Drop functions that might already exist with different signatures
DROP FUNCTION IF EXISTS public.debug_db_info();
DROP FUNCTION IF EXISTS public.get_user_app_entry_status_v2(uuid);
DROP FUNCTION IF EXISTS public.get_user_id_by_email(text);
DROP FUNCTION IF EXISTS public.get_accommodation_availability(uuid, date, date);
DROP FUNCTION IF EXISTS public.update_application_tracking_field(uuid, boolean);
DROP FUNCTION IF EXISTS public.toggle_booking_reminder_for_user(uuid);
DROP FUNCTION IF EXISTS public.toggle_application_tracking_field(uuid);
DROP FUNCTION IF EXISTS public.update_admin_verdict(uuid, text);
DROP FUNCTION IF EXISTS public.create_confirmed_booking(text, uuid, date, date, numeric);
DROP FUNCTION IF EXISTS public.has_housekeeping_access();
DROP FUNCTION IF EXISTS public.admin_add_credits(uuid, numeric, text);
DROP FUNCTION IF EXISTS public.admin_remove_credits(uuid, numeric, text);

-- Also drop views if they exist
DROP VIEW IF EXISTS public.application_details CASCADE;
DROP VIEW IF EXISTS public.whitelist_user_details CASCADE;
DROP VIEW IF EXISTS public.bookings_with_details CASCADE;

-- Now you can run add_missing_views_and_rpcs.sql without conflicts