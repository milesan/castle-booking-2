// BROWSER CONSOLE SNIPPET TO MAKE andre@thegarden.pt ADMIN
// Run this in your browser console while on https://rooms.castle.community

// Step 1: Copy and paste this entire code into the browser console

(async function setupAdmin() {
  try {
    // Get Supabase client from the window (most Supabase apps expose this)
    const supabase = window.supabase || 
                     window.__supabase || 
                     (window.React && window.React.__SECRET_INTERNALS_DO_NOT_USE_OR_YOU_WILL_BE_FIRED?.ReactCurrentOwner?.current?.memoizedProps?.supabase);
    
    if (!supabase) {
      console.error('Could not find Supabase client. Try the SQL method instead.');
      return;
    }

    console.log('Setting up andre@thegarden.pt as admin...');

    // Create admin_users table
    const { error: tableError } = await supabase.rpc('exec_sql', {
      sql: `
        CREATE TABLE IF NOT EXISTS public.admin_users (
          id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
          email text UNIQUE NOT NULL,
          created_at timestamp with time zone DEFAULT timezone('utc'::text, now()) NOT NULL
        );
      `
    }).catch(() => ({ error: 'Table might already exist' }));

    // Add andre@thegarden.pt as admin
    const { error: insertError } = await supabase
      .from('admin_users')
      .upsert({ email: 'andre@thegarden.pt' }, { onConflict: 'email' });

    if (insertError && !insertError.message.includes('already exists')) {
      console.error('Error adding admin:', insertError);
    }

    console.log('✅ Admin setup complete! Please refresh the page and log in as andre@thegarden.pt');
    
  } catch (error) {
    console.error('Setup failed:', error);
    console.log('Please use the SQL method in Supabase Dashboard instead.');
  }
})();

// ============================================
// ALTERNATIVE: Direct SQL for Supabase Dashboard
// ============================================
/*
Go to: https://supabase.com/dashboard/project/ywsbmarhoyxercqatbfy/sql

Run this SQL:

BEGIN;

CREATE TABLE IF NOT EXISTS public.admin_users (
    id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
    email text UNIQUE NOT NULL,
    created_at timestamp with time zone DEFAULT timezone('utc'::text, now()) NOT NULL
);

TRUNCATE TABLE admin_users;

INSERT INTO admin_users (email) 
VALUES ('andre@thegarden.pt')
ON CONFLICT (email) DO NOTHING;

CREATE OR REPLACE FUNCTION public.is_admin()
RETURNS boolean AS $$
BEGIN
  RETURN (
    SELECT email = 'andre@thegarden.pt'
    FROM auth.users
    WHERE id = auth.uid()
  );
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

GRANT UPDATE ON accommodations TO authenticated;
GRANT ALL ON accommodations TO authenticated;

DROP POLICY IF EXISTS "Admin can update accommodations" ON accommodations;
CREATE POLICY "Admin can update accommodations"
  ON accommodations FOR UPDATE
  USING (public.is_admin())
  WITH CHECK (public.is_admin());

COMMIT;
*/