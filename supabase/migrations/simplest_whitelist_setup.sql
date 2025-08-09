-- SIMPLEST WHITELIST SETUP
-- Just use profiles table as the whitelist
-- If you're in it, you can login. If not, you can't.

-- 1. Clean up old functions that might conflict
DROP FUNCTION IF EXISTS public.is_admin(uuid);
DROP FUNCTION IF EXISTS public.is_admin();
DROP FUNCTION IF EXISTS public.add_user_to_whitelist(text);
DROP FUNCTION IF EXISTS public.remove_user_from_whitelist(uuid);

-- 2. Disable RLS temporarily
ALTER TABLE public.profiles DISABLE ROW LEVEL SECURITY;

-- 3. Drop ALL old policies
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

-- 4. Make sure profiles table has the columns we need
ALTER TABLE public.profiles 
  ALTER COLUMN email SET NOT NULL;

-- Add first_name and last_name if they don't exist
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

-- 5. Enable RLS with SIMPLE policies
ALTER TABLE public.profiles ENABLE ROW LEVEL SECURITY;

-- Anyone can read profiles (needed for login check)
CREATE POLICY "anyone_can_read" 
ON public.profiles FOR SELECT 
USING (true);

-- Only authenticated users can update their own profile
CREATE POLICY "users_update_own" 
ON public.profiles FOR UPDATE 
USING (auth.uid() = id);

-- Only existing admins can insert/delete (manage whitelist)
CREATE POLICY "admins_can_insert" 
ON public.profiles FOR INSERT 
WITH CHECK (
  EXISTS (
    SELECT 1 FROM public.profiles 
    WHERE id = auth.uid() AND is_admin = true
  )
);

CREATE POLICY "admins_can_delete" 
ON public.profiles FOR DELETE 
USING (
  EXISTS (
    SELECT 1 FROM public.profiles 
    WHERE id = auth.uid() AND is_admin = true
  )
);

-- 6. Create SIMPLE functions for admin operations

-- Add user to whitelist (just adds to profiles table)
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
  IF NOT EXISTS (
    SELECT 1 FROM public.profiles 
    WHERE id = auth.uid() AND is_admin = true
  ) THEN
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
END;
$$;

-- Remove user from whitelist (just removes from profiles)
CREATE OR REPLACE FUNCTION public.whitelist_remove_user(user_id uuid)
RETURNS json
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
BEGIN
  -- Check if caller is admin
  IF NOT EXISTS (
    SELECT 1 FROM public.profiles 
    WHERE id = auth.uid() AND is_admin = true
  ) THEN
    RETURN json_build_object('success', false, 'error', 'Not authorized');
  END IF;

  -- Don't let admin remove themselves
  IF user_id = auth.uid() THEN
    RETURN json_build_object('success', false, 'error', 'Cannot remove yourself');
  END IF;

  -- Remove from profiles
  DELETE FROM public.profiles WHERE id = user_id;

  RETURN json_build_object('success', true);
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
  IF NOT EXISTS (
    SELECT 1 FROM public.profiles 
    WHERE id = auth.uid() AND is_admin = true
  ) THEN
    RETURN json_build_object('success', false, 'error', 'Not authorized');
  END IF;

  -- Get current status
  SELECT is_admin INTO current_status 
  FROM public.profiles 
  WHERE id = user_id;

  -- Toggle it
  UPDATE public.profiles 
  SET is_admin = NOT COALESCE(current_status, false)
  WHERE id = user_id;

  RETURN json_build_object('success', true, 'new_status', NOT COALESCE(current_status, false));
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
BEGIN
  -- Check if caller is admin
  IF NOT EXISTS (
    SELECT 1 FROM public.profiles 
    WHERE id = auth.uid() AND is_admin = true
  ) THEN
    RETURN json_build_object('success', false, 'error', 'Not authorized');
  END IF;

  -- Process each user
  FOR user_record IN SELECT * FROM json_array_elements(users)
  LOOP
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
  END LOOP;

  RETURN json_build_object(
    'success', true,
    'added', added_count,
    'skipped', skipped_count
  );
END;
$$;

-- 7. Grant permissions
GRANT EXECUTE ON FUNCTION public.whitelist_add_user TO authenticated;
GRANT EXECUTE ON FUNCTION public.whitelist_remove_user TO authenticated;
GRANT EXECUTE ON FUNCTION public.whitelist_toggle_admin TO authenticated;
GRANT EXECUTE ON FUNCTION public.whitelist_bulk_import TO authenticated;

-- 8. Verify your admin status
UPDATE public.profiles 
SET is_admin = true 
WHERE email = 'redis213@gmail.com';

-- 9. Test the setup
SELECT 
  email,
  first_name,
  last_name,
  is_admin,
  created_at
FROM public.profiles
ORDER BY created_at DESC;