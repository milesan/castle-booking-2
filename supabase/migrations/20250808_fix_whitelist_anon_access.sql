-- Grant anonymous users access to whitelist_all view
-- This is needed for the login flow to check if a user is whitelisted before they authenticate

-- Grant SELECT permission on whitelist_all view to anonymous users
GRANT SELECT ON public.whitelist_all TO anon;

-- Also ensure the whitelist_pending table is accessible for the view
GRANT SELECT ON public.whitelist_pending TO anon;

-- Ensure profiles table is accessible for the view (with RLS)
GRANT SELECT ON public.profiles TO anon;