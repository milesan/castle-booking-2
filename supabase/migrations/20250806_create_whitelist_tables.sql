-- Create is_admin function if it doesn't exist
CREATE OR REPLACE FUNCTION public.is_admin() RETURNS boolean
    LANGUAGE plpgsql SECURITY DEFINER
    AS $$BEGIN
  RETURN EXISTS (
    SELECT 1 
    FROM auth.users 
    WHERE id = auth.uid() 
    AND email IN (
      'andre@thegarden.pt',
      'redis213@gmail.com',
      'dawn@thegarden.pt',
      'simone@thegarden.pt',
      'samjlloa@gmail.com',
      'living@thegarden.pt',
      'samckclarke@gmail.com'
    )
  );
END;$$;

-- Create whitelist table
CREATE TABLE IF NOT EXISTS public.whitelist (
    id uuid DEFAULT gen_random_uuid() NOT NULL,
    email text NOT NULL,
    notes text,
    created_at timestamp with time zone DEFAULT timezone('utc'::text, now()) NOT NULL,
    updated_at timestamp with time zone DEFAULT timezone('utc'::text, now()) NOT NULL,
    last_login timestamp with time zone,
    has_seen_welcome boolean DEFAULT false,
    has_created_account boolean DEFAULT false,
    account_created_at timestamp with time zone,
    has_booked boolean DEFAULT false,
    first_booking_at timestamp with time zone,
    last_booking_at timestamp with time zone,
    total_bookings integer DEFAULT 0,
    created_account_at timestamp with time zone,
    user_id uuid
);

-- Create whitelist_tokens table
CREATE TABLE IF NOT EXISTS public.whitelist_tokens (
    id uuid DEFAULT gen_random_uuid() NOT NULL,
    whitelist_id uuid NOT NULL,
    token text NOT NULL,
    created_at timestamp with time zone DEFAULT timezone('utc'::text, now()) NOT NULL,
    used_at timestamp with time zone
);

-- Add primary keys
ALTER TABLE ONLY public.whitelist
    ADD CONSTRAINT whitelist_pkey PRIMARY KEY (id);

ALTER TABLE ONLY public.whitelist_tokens
    ADD CONSTRAINT whitelist_tokens_pkey PRIMARY KEY (id);

-- Add unique constraints
ALTER TABLE ONLY public.whitelist
    ADD CONSTRAINT whitelist_email_key UNIQUE (email);

ALTER TABLE ONLY public.whitelist_tokens
    ADD CONSTRAINT whitelist_tokens_token_key UNIQUE (token);

-- Add foreign key constraints
ALTER TABLE ONLY public.whitelist
    ADD CONSTRAINT fk_auth_user FOREIGN KEY (user_id) REFERENCES auth.users(id) ON DELETE CASCADE;

ALTER TABLE ONLY public.whitelist_tokens
    ADD CONSTRAINT whitelist_tokens_whitelist_id_fkey FOREIGN KEY (whitelist_id) REFERENCES public.whitelist(id);

-- Create view for whitelist_user_details
CREATE OR REPLACE VIEW public.whitelist_user_details AS
 SELECT w.id,
    w.email,
    w.created_at,
    (u.id IS NOT NULL) AS has_account,
    u.last_sign_in_at,
    (EXISTS ( SELECT 1
           FROM public.applications app
          WHERE (app.user_id = u.id))) AS has_finished_signup
   FROM (public.whitelist w
     LEFT JOIN auth.users u ON ((w.email = (u.email)::text)));

-- Enable RLS
ALTER TABLE public.whitelist ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.whitelist_tokens ENABLE ROW LEVEL SECURITY;

-- Create RLS policies for whitelist table
CREATE POLICY "Admin full access to whitelist" 
    ON public.whitelist 
    USING (public.is_admin());

CREATE POLICY "Allow admin to insert" 
    ON public.whitelist 
    FOR INSERT 
    WITH CHECK (public.is_admin());

CREATE POLICY "Users can check their own whitelist status" 
    ON public.whitelist 
    FOR SELECT 
    USING ((email = auth.email()));

-- Create RLS policies for whitelist_tokens table
CREATE POLICY "Admin users can manage whitelist tokens" 
    ON public.whitelist_tokens 
    USING ((EXISTS ( SELECT 1
       FROM auth.users
      WHERE ((auth.uid() = users.id) AND ((users.raw_user_meta_data ->> 'isAdmin'::text) = 'true'::text)))));

CREATE POLICY "Authenticated users can view whitelist tokens" 
    ON public.whitelist_tokens 
    FOR SELECT 
    USING ((auth.role() = 'authenticated'::text));

CREATE POLICY "Enable read access for all users" 
    ON public.whitelist_tokens 
    FOR SELECT 
    USING (true);

CREATE POLICY "Everyone can update whitelist tokens" 
    ON public.whitelist_tokens 
    FOR UPDATE 
    USING (true) 
    WITH CHECK (true);

CREATE POLICY "Service role can manage whitelist tokens" 
    ON public.whitelist_tokens 
    USING (((auth.jwt() ->> 'role'::text) = 'service_role'::text));

-- Grant permissions
GRANT ALL ON TABLE public.whitelist TO service_role;
GRANT ALL ON TABLE public.whitelist TO authenticated;

GRANT ALL ON TABLE public.whitelist_tokens TO anon;
GRANT ALL ON TABLE public.whitelist_tokens TO authenticated;
GRANT ALL ON TABLE public.whitelist_tokens TO service_role;

GRANT ALL ON TABLE public.whitelist_user_details TO service_role;
GRANT SELECT ON TABLE public.whitelist_user_details TO authenticated;