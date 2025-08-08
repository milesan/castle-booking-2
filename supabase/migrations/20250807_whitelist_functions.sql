-- Create functions for whitelist management that admins can call

-- Function to add a user to whitelist
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

-- Function to remove a user from whitelist
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

  -- Delete the user (will cascade to auth.users if foreign key is set up)
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

-- Grant execute permissions to authenticated users
GRANT EXECUTE ON FUNCTION public.add_user_to_whitelist TO authenticated;
GRANT EXECUTE ON FUNCTION public.remove_user_from_whitelist TO authenticated;