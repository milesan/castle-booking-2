-- Make andre@thegarden.pt an admin user
-- Remove admin access from all other users

BEGIN;

-- First ensure the admin_users table exists
CREATE TABLE IF NOT EXISTS public.admin_users (
    id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
    email text UNIQUE NOT NULL,
    created_at timestamp with time zone DEFAULT timezone('utc'::text, now()) NOT NULL
);

-- Clear existing admin users
TRUNCATE TABLE admin_users;

-- Add andre@thegarden.pt as the only admin
INSERT INTO admin_users (email) 
VALUES ('andre@thegarden.pt')
ON CONFLICT (email) DO NOTHING;

-- Update the is_admin function to check for this specific email
CREATE OR REPLACE FUNCTION public.is_admin()
RETURNS boolean AS $$
BEGIN
  -- Check if the current user's email is andre@thegarden.pt
  RETURN (
    SELECT email = 'andre@thegarden.pt'
    FROM auth.users
    WHERE id = auth.uid()
  );
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- Grant necessary permissions for admin to update accommodations
GRANT UPDATE ON accommodations TO authenticated;
GRANT ALL ON accommodations TO authenticated;

-- Create RLS policy for admin to update accommodations
CREATE POLICY "Admin can update accommodations"
  ON accommodations FOR UPDATE
  USING (public.is_admin())
  WITH CHECK (public.is_admin());

COMMIT;