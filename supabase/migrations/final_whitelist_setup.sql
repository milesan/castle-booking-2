-- FINAL SIMPLIFIED WHITELIST SETUP
-- Run AFTER fix_is_admin_functions.sql

-- 1. Create whitelist management functions

-- Add user to whitelist
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
  new_user_id uuid;
BEGIN
  -- Check if caller is admin
  IF NOT public.is_admin() THEN
    RETURN json_build_object('success', false, 'error', 'Not authorized');
  END IF;

  -- Normalize email
  user_email := lower(trim(user_email));

  -- Check if user already exists
  IF EXISTS (SELECT 1 FROM public.profiles WHERE email = user_email) THEN
    RETURN json_build_object('success', false, 'error', 'User already exists');
  END IF;

  -- Create new user ID
  new_user_id := gen_random_uuid();

  -- Add to profiles (this IS the whitelist)
  INSERT INTO public.profiles (id, email, first_name, last_name, is_admin, created_at)
  VALUES (new_user_id, user_email, user_first_name, user_last_name, make_admin, now());

  RETURN json_build_object(
    'success', true, 
    'user_id', new_user_id,
    'email', user_email
  );
EXCEPTION
  WHEN OTHERS THEN
    RETURN json_build_object('success', false, 'error', SQLERRM);
END;
$$;

-- Remove user from whitelist
CREATE OR REPLACE FUNCTION public.whitelist_remove_user(user_id uuid)
RETURNS json
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
BEGIN
  -- Check if caller is admin
  IF NOT public.is_admin() THEN
    RETURN json_build_object('success', false, 'error', 'Not authorized');
  END IF;

  -- Don't let admin remove themselves
  IF user_id = auth.uid() THEN
    RETURN json_build_object('success', false, 'error', 'Cannot remove yourself');
  END IF;

  -- Remove from profiles
  DELETE FROM public.profiles WHERE id = user_id;

  IF NOT FOUND THEN
    RETURN json_build_object('success', false, 'error', 'User not found');
  END IF;

  RETURN json_build_object('success', true);
EXCEPTION
  WHEN OTHERS THEN
    RETURN json_build_object('success', false, 'error', SQLERRM);
END;
$$;

-- Toggle admin status
CREATE OR REPLACE FUNCTION public.whitelist_toggle_admin(user_id uuid)
RETURNS json
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
DECLARE
  current_status boolean;
BEGIN
  -- Check if caller is admin
  IF NOT public.is_admin() THEN
    RETURN json_build_object('success', false, 'error', 'Not authorized');
  END IF;

  -- Get current status
  SELECT is_admin INTO current_status 
  FROM public.profiles 
  WHERE id = user_id;

  IF NOT FOUND THEN
    RETURN json_build_object('success', false, 'error', 'User not found');
  END IF;

  -- Toggle it
  UPDATE public.profiles 
  SET is_admin = NOT COALESCE(current_status, false)
  WHERE id = user_id;

  RETURN json_build_object('success', true, 'new_status', NOT COALESCE(current_status, false));
EXCEPTION
  WHEN OTHERS THEN
    RETURN json_build_object('success', false, 'error', SQLERRM);
END;
$$;

-- Bulk import from CSV data
CREATE OR REPLACE FUNCTION public.whitelist_bulk_import(users json)
RETURNS json
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
DECLARE
  user_record json;
  added_count int := 0;
  skipped_count int := 0;
  error_count int := 0;
  error_messages text[] := '{}';
BEGIN
  -- Check if caller is admin
  IF NOT public.is_admin() THEN
    RETURN json_build_object('success', false, 'error', 'Not authorized');
  END IF;

  -- Process each user
  FOR user_record IN SELECT * FROM json_array_elements(users)
  LOOP
    BEGIN
      -- Skip if email already exists
      IF EXISTS (
        SELECT 1 FROM public.profiles 
        WHERE email = lower(user_record->>'email')
      ) THEN
        skipped_count := skipped_count + 1;
        CONTINUE;
      END IF;

      -- Insert new user
      INSERT INTO public.profiles (
        id, 
        email, 
        first_name, 
        last_name, 
        is_admin, 
        created_at
      ) VALUES (
        gen_random_uuid(),
        lower(user_record->>'email'),
        user_record->>'first_name',
        user_record->>'last_name',
        COALESCE((user_record->>'is_admin')::boolean, false),
        now()
      );
      
      added_count := added_count + 1;
    EXCEPTION
      WHEN OTHERS THEN
        error_count := error_count + 1;
        error_messages := array_append(error_messages, 
          format('%s: %s', user_record->>'email', SQLERRM));
    END;
  END LOOP;

  RETURN json_build_object(
    'success', true,
    'added', added_count,
    'skipped', skipped_count,
    'errors', error_count,
    'error_details', error_messages
  );
END;
$$;

-- 2. Grant permissions
GRANT EXECUTE ON FUNCTION public.whitelist_add_user TO authenticated;
GRANT EXECUTE ON FUNCTION public.whitelist_remove_user TO authenticated;
GRANT EXECUTE ON FUNCTION public.whitelist_toggle_admin TO authenticated;
GRANT EXECUTE ON FUNCTION public.whitelist_bulk_import TO authenticated;

-- 3. Ensure you are an admin
UPDATE public.profiles 
SET is_admin = true 
WHERE email = 'redis213@gmail.com';

-- 4. Add test users to verify it works
SELECT whitelist_add_user('test1@example.com', 'Test', 'User', false) as add_test_user;
SELECT whitelist_add_user('admin2@example.com', 'Admin', 'Two', true) as add_admin_user;

-- 5. Show current whitelist
SELECT 
  email,
  first_name || ' ' || last_name as name,
  CASE WHEN is_admin THEN '👑 Admin' ELSE '👤 User' END as role,
  created_at::date as added
FROM public.profiles
ORDER BY created_at DESC;

-- 6. Clean up test users (optional - uncomment to remove)
-- DELETE FROM public.profiles WHERE email IN ('test1@example.com', 'admin2@example.com');