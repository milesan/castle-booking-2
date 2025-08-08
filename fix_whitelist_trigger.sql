-- Fix the whitelist activation trigger
-- This runs when a new auth.users record is created

-- 1. First, check if the trigger exists
SELECT 
    tgname as trigger_name,
    tgrelid::regclass as table_name,
    proname as function_name
FROM pg_trigger 
JOIN pg_proc ON pg_proc.oid = pg_trigger.tgfoid
WHERE tgrelid = 'auth.users'::regclass
AND tgname = 'auto_activate_whitelist_trigger';

-- 2. Drop the existing trigger if it exists
DROP TRIGGER IF EXISTS auto_activate_whitelist_trigger ON auth.users;

-- 3. Create a simpler, more reliable activation function
CREATE OR REPLACE FUNCTION public.handle_new_user()
RETURNS trigger
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  pending_record public.whitelist_pending;
BEGIN
  -- Log for debugging
  RAISE LOG 'handle_new_user triggered for email: %', NEW.email;
  
  -- Check if user is in pending whitelist
  SELECT * INTO pending_record
  FROM public.whitelist_pending 
  WHERE email = lower(NEW.email);
  
  IF pending_record.email IS NOT NULL THEN
    -- User is in pending whitelist, create profile
    INSERT INTO public.profiles (
      id, 
      email, 
      first_name, 
      last_name, 
      is_admin, 
      created_at
    ) VALUES (
      NEW.id,
      lower(NEW.email),
      pending_record.first_name,
      pending_record.last_name,
      pending_record.is_admin,
      now()
    ) ON CONFLICT (id) DO UPDATE SET
      first_name = COALESCE(EXCLUDED.first_name, profiles.first_name),
      last_name = COALESCE(EXCLUDED.last_name, profiles.last_name),
      is_admin = COALESCE(EXCLUDED.is_admin, profiles.is_admin);
    
    -- Remove from pending
    DELETE FROM public.whitelist_pending WHERE email = lower(NEW.email);
    
    RAISE LOG 'User % moved from pending to active', NEW.email;
  ELSE
    -- User not in pending, just create basic profile if not exists
    INSERT INTO public.profiles (id, email, created_at)
    VALUES (NEW.id, lower(NEW.email), now())
    ON CONFLICT (id) DO NOTHING;
    
    RAISE LOG 'Basic profile created for %', NEW.email;
  END IF;
  
  RETURN NEW;
EXCEPTION
  WHEN OTHERS THEN
    -- Log error but don't fail the auth signup
    RAISE LOG 'Error in handle_new_user for %: %', NEW.email, SQLERRM;
    RETURN NEW;
END;
$$;

-- 4. Drop existing trigger if it exists and create new one
DROP TRIGGER IF EXISTS on_auth_user_created ON auth.users;

CREATE TRIGGER on_auth_user_created
  AFTER INSERT ON auth.users
  FOR EACH ROW
  EXECUTE FUNCTION public.handle_new_user();

-- 5. Grant necessary permissions
GRANT USAGE ON SCHEMA public TO postgres, anon, authenticated, service_role;
GRANT ALL ON public.profiles TO postgres, service_role;
GRANT SELECT, INSERT, UPDATE ON public.profiles TO authenticated;
GRANT SELECT ON public.whitelist_pending TO postgres, service_role, authenticated;
GRANT DELETE ON public.whitelist_pending TO postgres, service_role;

-- 6. Ensure RLS doesn't block the trigger function
ALTER TABLE public.profiles DISABLE ROW LEVEL SECURITY;
ALTER TABLE public.profiles ENABLE ROW LEVEL SECURITY;

-- Create a policy that allows the trigger to insert
CREATE POLICY "service_role_all" ON public.profiles
  FOR ALL 
  TO service_role
  USING (true)
  WITH CHECK (true);

-- 7. Test by checking current pending users
SELECT 'Current pending users:' as info;
SELECT email, first_name, last_name, is_admin 
FROM public.whitelist_pending 
ORDER BY created_at DESC;

-- 8. Add a test pending user if none exist
DO $$
BEGIN
  IF NOT EXISTS (SELECT 1 FROM public.whitelist_pending LIMIT 1) THEN
    INSERT INTO public.whitelist_pending (email, first_name, last_name, is_admin, added_by)
    VALUES ('testpending@example.com', 'Test', 'Pending', false, NULL);
    RAISE NOTICE 'Added test pending user: testpending@example.com';
  END IF;
END $$;

SELECT 'Trigger setup complete. Pending users will now be activated when they sign up.' as status;