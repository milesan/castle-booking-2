-- Fix the foreign key issue when adding users to whitelist
-- Option 2: Keep foreign key but handle with pending whitelist table

-- Main function to add user (checks auth.users first, then adds to pending if needed)
CREATE OR REPLACE FUNCTION public.whitelist_add_user(
  user_email text,
  user_first_name text DEFAULT NULL,
  user_last_name text DEFAULT NULL,
  make_admin boolean DEFAULT false
)
RETURNS json
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
DECLARE
  existing_auth_user auth.users;
  existing_profile public.profiles;
  result json;
BEGIN
  -- Check if caller is admin
  IF NOT public.is_admin() THEN
    RETURN json_build_object('success', false, 'error', 'Not authorized');
  END IF;

  -- Normalize email
  user_email := lower(trim(user_email));

  -- Check if profile already exists
  SELECT * INTO existing_profile
  FROM public.profiles 
  WHERE email = user_email;
  
  IF existing_profile.id IS NOT NULL THEN
    RETURN json_build_object('success', false, 'error', 'User already in whitelist');
  END IF;

  -- Check if auth user exists
  SELECT * INTO existing_auth_user
  FROM auth.users 
  WHERE email = user_email;

  IF existing_auth_user.id IS NOT NULL THEN
    -- Auth user exists, create profile for them
    INSERT INTO public.profiles (id, email, first_name, last_name, is_admin, created_at)
    VALUES (existing_auth_user.id, user_email, user_first_name, user_last_name, make_admin, now());

    RETURN json_build_object(
      'success', true, 
      'user_id', existing_auth_user.id,
      'email', user_email,
      'status', 'active',
      'note', 'User added to whitelist (has auth account)'
    );
  ELSE
    -- No auth user exists - add to pending whitelist
    SELECT whitelist_add_pending(user_email, user_first_name, user_last_name, make_admin) INTO result;
    RETURN result;
  END IF;

EXCEPTION
  WHEN OTHERS THEN
    RETURN json_build_object('success', false, 'error', SQLERRM);
END;
$$;

-- Create a staging table for whitelist entries without auth users
CREATE TABLE IF NOT EXISTS public.whitelist_pending (
  email text PRIMARY KEY,
  first_name text,
  last_name text,
  is_admin boolean DEFAULT false,
  added_by uuid REFERENCES public.profiles(id),
  created_at timestamp with time zone DEFAULT now()
);

-- Function to add to pending whitelist (no auth user required)
CREATE OR REPLACE FUNCTION public.whitelist_add_pending(
  user_email text,
  user_first_name text DEFAULT NULL,
  user_last_name text DEFAULT NULL,
  make_admin boolean DEFAULT false
)
RETURNS json
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
BEGIN
  -- Check if caller is admin
  IF NOT public.is_admin() THEN
    RETURN json_build_object('success', false, 'error', 'Not authorized');
  END IF;

  -- Normalize email
  user_email := lower(trim(user_email));

  -- Check if already in profiles
  IF EXISTS (SELECT 1 FROM public.profiles WHERE email = user_email) THEN
    RETURN json_build_object('success', false, 'error', 'User already in whitelist');
  END IF;

  -- Check if already in pending
  IF EXISTS (SELECT 1 FROM public.whitelist_pending WHERE email = user_email) THEN
    -- Update existing pending entry
    UPDATE public.whitelist_pending 
    SET first_name = user_first_name,
        last_name = user_last_name,
        is_admin = make_admin,
        added_by = auth.uid(),
        created_at = now()
    WHERE email = user_email;
  ELSE
    -- Add to pending whitelist
    INSERT INTO public.whitelist_pending (email, first_name, last_name, is_admin, added_by)
    VALUES (user_email, user_first_name, user_last_name, make_admin, auth.uid());
  END IF;

  RETURN json_build_object(
    'success', true,
    'email', user_email,
    'status', 'pending',
    'note', 'User added to whitelist. They will be activated on first login attempt.'
  );
EXCEPTION
  WHEN OTHERS THEN
    RETURN json_build_object('success', false, 'error', SQLERRM);
END;
$$;

-- Function to check whitelist (including pending)
CREATE OR REPLACE FUNCTION public.check_whitelist(user_email text)
RETURNS json
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
DECLARE
  profile_exists boolean;
  pending_exists boolean;
  pending_record public.whitelist_pending;
BEGIN
  user_email := lower(trim(user_email));
  
  -- Check if in profiles
  SELECT EXISTS(SELECT 1 FROM public.profiles WHERE email = user_email) INTO profile_exists;
  
  IF profile_exists THEN
    RETURN json_build_object(
      'whitelisted', true,
      'status', 'active',
      'can_login', true
    );
  END IF;
  
  -- Check if in pending
  SELECT * INTO pending_record
  FROM public.whitelist_pending 
  WHERE email = user_email;
  
  IF pending_record.email IS NOT NULL THEN
    RETURN json_build_object(
      'whitelisted', true,
      'status', 'pending',
      'can_login', true,
      'first_name', pending_record.first_name,
      'last_name', pending_record.last_name,
      'is_admin', pending_record.is_admin
    );
  END IF;
  
  -- Not whitelisted
  RETURN json_build_object(
    'whitelisted', false,
    'status', 'not_whitelisted',
    'can_login', false
  );
END;
$$;

-- Function to activate pending user (called after auth user creation)
CREATE OR REPLACE FUNCTION public.activate_pending_user(user_id uuid, user_email text)
RETURNS json
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
DECLARE
  pending_record public.whitelist_pending;
BEGIN
  user_email := lower(trim(user_email));
  
  -- Get pending record
  SELECT * INTO pending_record
  FROM public.whitelist_pending 
  WHERE email = user_email;
  
  IF pending_record.email IS NULL THEN
    -- Not in pending, just create basic profile
    INSERT INTO public.profiles (id, email, created_at)
    VALUES (user_id, user_email, now())
    ON CONFLICT (id) DO NOTHING;
    
    RETURN json_build_object('success', true, 'status', 'created_basic');
  END IF;
  
  -- Create profile from pending data
  INSERT INTO public.profiles (id, email, first_name, last_name, is_admin, created_at)
  VALUES (user_id, user_email, pending_record.first_name, pending_record.last_name, pending_record.is_admin, now())
  ON CONFLICT (id) DO UPDATE SET
    first_name = EXCLUDED.first_name,
    last_name = EXCLUDED.last_name,
    is_admin = EXCLUDED.is_admin;
  
  -- Remove from pending
  DELETE FROM public.whitelist_pending WHERE email = user_email;
  
  RETURN json_build_object('success', true, 'status', 'activated');
END;
$$;

-- Trigger to auto-activate pending users when they sign up
CREATE OR REPLACE FUNCTION public.auto_activate_whitelist()
RETURNS trigger
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
BEGIN
  -- When a new auth user is created, check if they're in pending whitelist
  IF EXISTS (SELECT 1 FROM public.whitelist_pending WHERE email = NEW.email) THEN
    PERFORM public.activate_pending_user(NEW.id, NEW.email);
  END IF;
  RETURN NEW;
END;
$$;

-- Create trigger on auth.users (if not exists)
DROP TRIGGER IF EXISTS auto_activate_whitelist_trigger ON auth.users;
CREATE TRIGGER auto_activate_whitelist_trigger
AFTER INSERT ON auth.users
FOR EACH ROW
EXECUTE FUNCTION public.auto_activate_whitelist();

-- Grant permissions
GRANT EXECUTE ON FUNCTION public.whitelist_add_user TO authenticated;
GRANT EXECUTE ON FUNCTION public.whitelist_add_pending TO authenticated;
GRANT EXECUTE ON FUNCTION public.check_whitelist TO authenticated, anon;
GRANT EXECUTE ON FUNCTION public.activate_pending_user TO authenticated;
GRANT SELECT ON public.whitelist_pending TO authenticated;

-- Create a unified view for the admin panel
CREATE OR REPLACE VIEW public.whitelist_all AS
SELECT 
  p.id,
  p.email,
  p.first_name,
  p.last_name,
  p.is_admin,
  p.created_at,
  'active' as status
FROM public.profiles p
UNION ALL
SELECT 
  null as id,
  wp.email,
  wp.first_name,
  wp.last_name,
  wp.is_admin,
  wp.created_at,
  'pending' as status
FROM public.whitelist_pending wp
ORDER BY created_at DESC;

GRANT SELECT ON public.whitelist_all TO authenticated;

-- Function to remove user from whitelist (both active and pending)
CREATE OR REPLACE FUNCTION public.whitelist_remove_user(user_id_or_email text)
RETURNS json
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
DECLARE
  removed_count int := 0;
BEGIN
  -- Check if caller is admin
  IF NOT public.is_admin() THEN
    RETURN json_build_object('success', false, 'error', 'Not authorized');
  END IF;

  -- Try to remove from profiles by ID (if it's a UUID)
  IF user_id_or_email ~ '^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$' THEN
    DELETE FROM public.profiles WHERE id = user_id_or_email::uuid;
    removed_count := removed_count + FOUND::int;
  END IF;
  
  -- Try to remove from profiles by email
  DELETE FROM public.profiles WHERE email = lower(user_id_or_email);
  removed_count := removed_count + FOUND::int;
  
  -- Try to remove from pending by email
  DELETE FROM public.whitelist_pending WHERE email = lower(user_id_or_email);
  removed_count := removed_count + FOUND::int;

  IF removed_count > 0 THEN
    RETURN json_build_object('success', true, 'removed', removed_count);
  ELSE
    RETURN json_build_object('success', false, 'error', 'User not found');
  END IF;
EXCEPTION
  WHEN OTHERS THEN
    RETURN json_build_object('success', false, 'error', SQLERRM);
END;
$$;

-- Function to toggle admin status (works for both active and pending)
CREATE OR REPLACE FUNCTION public.whitelist_toggle_admin(user_id_or_email text)
RETURNS json
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
DECLARE
  current_status boolean;
  updated_count int := 0;
BEGIN
  -- Check if caller is admin
  IF NOT public.is_admin() THEN
    RETURN json_build_object('success', false, 'error', 'Not authorized');
  END IF;

  -- Try to update profiles by ID (if it's a UUID)
  IF user_id_or_email ~ '^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$' THEN
    SELECT is_admin INTO current_status FROM public.profiles WHERE id = user_id_or_email::uuid;
    IF FOUND THEN
      UPDATE public.profiles 
      SET is_admin = NOT COALESCE(current_status, false)
      WHERE id = user_id_or_email::uuid;
      RETURN json_build_object('success', true, 'new_status', NOT COALESCE(current_status, false));
    END IF;
  END IF;
  
  -- Try to update profiles by email
  SELECT is_admin INTO current_status FROM public.profiles WHERE email = lower(user_id_or_email);
  IF FOUND THEN
    UPDATE public.profiles 
    SET is_admin = NOT COALESCE(current_status, false)
    WHERE email = lower(user_id_or_email);
    RETURN json_build_object('success', true, 'new_status', NOT COALESCE(current_status, false));
  END IF;
  
  -- Try to update pending by email
  SELECT is_admin INTO current_status FROM public.whitelist_pending WHERE email = lower(user_id_or_email);
  IF FOUND THEN
    UPDATE public.whitelist_pending 
    SET is_admin = NOT COALESCE(current_status, false)
    WHERE email = lower(user_id_or_email);
    RETURN json_build_object('success', true, 'new_status', NOT COALESCE(current_status, false), 'status', 'pending');
  END IF;

  RETURN json_build_object('success', false, 'error', 'User not found');
EXCEPTION
  WHEN OTHERS THEN
    RETURN json_build_object('success', false, 'error', SQLERRM);
END;
$$;

-- Grant additional permissions
GRANT EXECUTE ON FUNCTION public.whitelist_remove_user TO authenticated;
GRANT EXECUTE ON FUNCTION public.whitelist_toggle_admin TO authenticated;

-- Test the system
SELECT 'Current Whitelist (Active):' as info;
SELECT email, first_name, last_name, is_admin FROM public.profiles ORDER BY created_at DESC;

SELECT 'Current Whitelist (Pending):' as info;
SELECT email, first_name, last_name, is_admin FROM public.whitelist_pending ORDER BY created_at DESC;

SELECT 'Unified Whitelist View:' as info;
SELECT * FROM public.whitelist_all ORDER BY created_at DESC;