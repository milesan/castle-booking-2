-- SIMPLEST WHITELIST SETUP - FIXED VERSION
-- Keeps existing is_admin() function that other tables depend on

-- 1. Keep the existing is_admin function (other tables need it)
-- Just make sure it exists and works correctly
CREATE OR REPLACE FUNCTION public.is_admin()
RETURNS boolean
LANGUAGE sql
SECURITY DEFINER
STABLE
AS $$
  SELECT COALESCE(
    (SELECT is_admin FROM public.profiles WHERE id = auth.uid() LIMIT 1),
    false
  );
$$;

-- 2. Clean up only the whitelist-specific functions
DROP FUNCTION IF EXISTS public.add_user_to_whitelist(text);
DROP FUNCTION IF EXISTS public.remove_user_from_whitelist(uuid);

-- 3. Disable RLS temporarily to fix policies
ALTER TABLE public.profiles DISABLE ROW LEVEL SECURITY;

-- 4. Drop ALL policies on profiles table only
DO $$ 
DECLARE
    pol record;
BEGIN
    FOR pol IN 
        SELECT policyname 
        FROM pg_policies 
        WHERE schemaname = 'public' 
        AND tablename = 'profiles'
    LOOP
        EXECUTE format('DROP POLICY IF EXISTS %I ON public.profiles', pol.policyname);
    END LOOP;
END $$;

-- 5. Make sure profiles table has the columns we need
ALTER TABLE public.profiles 
  ALTER COLUMN email SET NOT NULL;

-- Add columns if they don't exist
DO $$ 
BEGIN
  IF NOT EXISTS (SELECT 1 FROM information_schema.columns 
                WHERE table_name = 'profiles' AND column_name = 'first_name') THEN
    ALTER TABLE public.profiles ADD COLUMN first_name text;
  END IF;
  
  IF NOT EXISTS (SELECT 1 FROM information_schema.columns 
                WHERE table_name = 'profiles' AND column_name = 'last_name') THEN
    ALTER TABLE public.profiles ADD COLUMN last_name text;
  END IF;
END $$;

-- 6. Enable RLS with SIMPLE policies
ALTER TABLE public.profiles ENABLE ROW LEVEL SECURITY;

-- Anyone can read profiles (needed for login check)
CREATE POLICY "anyone_can_read" 
ON public.profiles FOR SELECT 
USING (true);

-- Only authenticated users can update their own profile
CREATE POLICY "users_update_own" 
ON public.profiles FOR UPDATE 
USING (auth.uid() = id);

-- Only admins can insert (add to whitelist)
CREATE POLICY "admins_can_insert" 
ON public.profiles FOR INSERT 
WITH CHECK (is_admin());

-- Only admins can delete (remove from whitelist)
CREATE POLICY "admins_can_delete" 
ON public.profiles FOR DELETE 
USING (is_admin());

-- 7. Create SIMPLE functions for whitelist management

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
  -- Check if caller is admin using the existing is_admin() function
  IF NOT is_admin() THEN
    RETURN json_build_object('success', false, 'error', 'Not authorized');
  END IF;

  -- Check if user already exists
  IF EXISTS (SELECT 1 FROM public.profiles WHERE email = lower(user_email)) THEN
    RETURN json_build_object('success', false, 'error', 'User already exists');
  END IF;

  -- Create new user ID
  new_user_id := gen_random_uuid();

  -- Add to profiles (this IS the whitelist)
  INSERT INTO public.profiles (id, email, first_name, last_name, is_admin, created_at)
  VALUES (new_user_id, lower(user_email), user_first_name, user_last_name, make_admin, now());

  RETURN json_build_object(
    'success', true, 
    'user_id', new_user_id,
    'email', lower(user_email)
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
  IF NOT is_admin() THEN
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
  IF NOT is_admin() THEN
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
BEGIN
  -- Check if caller is admin
  IF NOT is_admin() THEN
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
    END;
  END LOOP;

  RETURN json_build_object(
    'success', true,
    'added', added_count,
    'skipped', skipped_count,
    'errors', error_count
  );
END;
$$;

-- 8. Grant permissions
GRANT EXECUTE ON FUNCTION public.whitelist_add_user TO authenticated;
GRANT EXECUTE ON FUNCTION public.whitelist_remove_user TO authenticated;
GRANT EXECUTE ON FUNCTION public.whitelist_toggle_admin TO authenticated;
GRANT EXECUTE ON FUNCTION public.whitelist_bulk_import TO authenticated;
GRANT EXECUTE ON FUNCTION public.is_admin TO authenticated, anon;

-- 9. Ensure you are an admin
UPDATE public.profiles 
SET is_admin = true 
WHERE email = 'redis213@gmail.com';

-- 10. Test the setup
SELECT 
  'Current Whitelist' as info,
  COUNT(*) as total_users,
  COUNT(CASE WHEN is_admin = true THEN 1 END) as admins
FROM public.profiles;

SELECT 
  email,
  first_name,
  last_name,
  is_admin,
  created_at
FROM public.profiles
ORDER BY created_at DESC;