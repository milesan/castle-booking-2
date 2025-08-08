-- Simple Whitelist Setup
-- Run this in Supabase SQL Editor

-- 1. Ensure profiles table has proper structure
ALTER TABLE public.profiles 
ALTER COLUMN email SET NOT NULL;

-- Add unique constraint on email if not exists
DO $$ 
BEGIN
  IF NOT EXISTS (
    SELECT 1 FROM pg_constraint 
    WHERE conname = 'profiles_email_key'
  ) THEN
    ALTER TABLE public.profiles 
    ADD CONSTRAINT profiles_email_key UNIQUE (email);
  END IF;
END $$;

-- 2. Create function to add user to whitelist
CREATE OR REPLACE FUNCTION public.add_user_to_whitelist(user_email text)
RETURNS json
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
DECLARE
  v_user_id uuid;
  v_result json;
BEGIN
  -- Check if caller is admin
  IF NOT EXISTS (
    SELECT 1 FROM public.profiles 
    WHERE id = auth.uid() 
    AND is_admin = true
  ) THEN
    RETURN json_build_object('success', false, 'error', 'Admin access required');
  END IF;

  -- Normalize email
  user_email := lower(trim(user_email));

  -- Validate email format
  IF user_email !~ '^[a-zA-Z0-9._%+-]+@[a-zA-Z0-9.-]+\.[a-zA-Z]{2,}$' THEN
    RETURN json_build_object('success', false, 'error', 'Invalid email format');
  END IF;

  -- Check if user already exists
  IF EXISTS (
    SELECT 1 FROM public.profiles 
    WHERE email = user_email
  ) THEN
    RETURN json_build_object('success', false, 'error', 'User already exists in whitelist');
  END IF;

  -- Generate a new UUID for the user
  v_user_id := gen_random_uuid();

  -- Insert into profiles (this creates the whitelist entry)
  INSERT INTO public.profiles (id, email, created_at)
  VALUES (v_user_id, user_email, now());

  RETURN json_build_object(
    'success', true, 
    'user_id', v_user_id,
    'email', user_email
  );

EXCEPTION
  WHEN OTHERS THEN
    RETURN json_build_object('success', false, 'error', SQLERRM);
END;
$$;

-- 3. Create function to remove user from whitelist
CREATE OR REPLACE FUNCTION public.remove_user_from_whitelist(user_id uuid)
RETURNS json
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
BEGIN
  -- Check if caller is admin
  IF NOT EXISTS (
    SELECT 1 FROM public.profiles 
    WHERE id = auth.uid() 
    AND is_admin = true
  ) THEN
    RETURN json_build_object('success', false, 'error', 'Admin access required');
  END IF;

  -- Don't allow removing yourself
  IF user_id = auth.uid() THEN
    RETURN json_build_object('success', false, 'error', 'Cannot remove yourself from whitelist');
  END IF;

  -- Delete the user
  DELETE FROM public.profiles WHERE id = user_id;

  IF NOT FOUND THEN
    RETURN json_build_object('success', false, 'error', 'User not found');
  END IF;

  RETURN json_build_object('success', true, 'user_id', user_id);

EXCEPTION
  WHEN OTHERS THEN
    RETURN json_build_object('success', false, 'error', SQLERRM);
END;
$$;

-- 4. Set up RLS policies for profiles table
ALTER TABLE public.profiles ENABLE ROW LEVEL SECURITY;

-- Drop existing policies
DROP POLICY IF EXISTS "Users can view own profile" ON public.profiles;
DROP POLICY IF EXISTS "Users can update own profile" ON public.profiles;
DROP POLICY IF EXISTS "Admins can view all profiles" ON public.profiles;
DROP POLICY IF EXISTS "Admins can update all profiles" ON public.profiles;
DROP POLICY IF EXISTS "Public can check whitelist" ON public.profiles;

-- Allow anyone to check if an email is whitelisted (for login check)
CREATE POLICY "Public can check whitelist" 
ON public.profiles
FOR SELECT
TO public
USING (true);

-- Users can update their own profile (except is_admin field)
CREATE POLICY "Users can update own profile" 
ON public.profiles
FOR UPDATE
TO authenticated
USING (auth.uid() = id)
WITH CHECK (
  auth.uid() = id 
  AND is_admin = (SELECT is_admin FROM public.profiles WHERE id = auth.uid())
);

-- Admins can update any profile
CREATE POLICY "Admins can update all profiles" 
ON public.profiles
FOR UPDATE
TO authenticated
USING (
  EXISTS (
    SELECT 1 FROM public.profiles
    WHERE profiles.id = auth.uid()
    AND profiles.is_admin = true
  )
)
WITH CHECK (
  EXISTS (
    SELECT 1 FROM public.profiles
    WHERE profiles.id = auth.uid()
    AND profiles.is_admin = true
  )
);

-- 5. Grant permissions
GRANT EXECUTE ON FUNCTION public.add_user_to_whitelist TO authenticated;
GRANT EXECUTE ON FUNCTION public.remove_user_from_whitelist TO authenticated;
GRANT SELECT ON public.profiles TO anon, authenticated;
GRANT UPDATE (first_name, last_name, phone, avatar_url) ON public.profiles TO authenticated;

-- 6. Create a trigger to sync auth.users email with profiles email
CREATE OR REPLACE FUNCTION public.sync_auth_email()
RETURNS TRIGGER
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
BEGIN
  -- When a profile is created, ensure auth.users has the same email
  IF TG_OP = 'INSERT' THEN
    -- Check if auth user exists
    IF NOT EXISTS (
      SELECT 1 FROM auth.users 
      WHERE id = NEW.id
    ) THEN
      -- We'll let Supabase Auth handle user creation
      -- Just ensure the email is stored
      NULL;
    END IF;
  END IF;
  
  RETURN NEW;
END;
$$;

DROP TRIGGER IF EXISTS sync_auth_email_trigger ON public.profiles;
CREATE TRIGGER sync_auth_email_trigger
AFTER INSERT ON public.profiles
FOR EACH ROW
EXECUTE FUNCTION public.sync_auth_email();

-- 7. Test the setup - check current whitelist
SELECT 
  id,
  email,
  first_name,
  last_name,
  is_admin,
  created_at
FROM public.profiles
ORDER BY created_at DESC;

-- 8. Make the first user an admin (replace with your email)
-- UPDATE public.profiles 
-- SET is_admin = true 
-- WHERE email = 'your-email@example.com';