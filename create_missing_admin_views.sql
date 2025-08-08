-- Create missing views for admin panel

-- 1. Drop and recreate bookings_with_emails view
DROP VIEW IF EXISTS public.bookings_with_emails CASCADE;
CREATE VIEW public.bookings_with_emails AS
SELECT 
    b.*,
    p.email as user_email,
    b.discount_code as applied_discount_code
FROM 
    public.bookings b
    LEFT JOIN public.profiles p ON b.user_id = p.id;

-- Grant permissions
GRANT SELECT ON public.bookings_with_emails TO authenticated;
GRANT SELECT ON public.bookings_with_emails TO service_role;

-- 2. Create application_questions_2 table (or rename existing one)
-- First check if application_questions exists and rename it
DO $$
BEGIN
    IF EXISTS (SELECT 1 FROM information_schema.tables 
               WHERE table_schema = 'public' 
               AND table_name = 'application_questions') THEN
        -- Rename the existing table
        ALTER TABLE public.application_questions RENAME TO application_questions_2;
    ELSIF NOT EXISTS (SELECT 1 FROM information_schema.tables 
                      WHERE table_schema = 'public' 
                      AND table_name = 'application_questions_2') THEN
        -- Create new table if neither exists
        CREATE TABLE public.application_questions_2 (
            id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
            question_text TEXT NOT NULL,
            question_type TEXT NOT NULL,
            options TEXT[],
            is_required BOOLEAN DEFAULT true,
            order_number INTEGER NOT NULL,
            section TEXT,
            section_intro_markdown TEXT,
            created_at TIMESTAMP WITH TIME ZONE DEFAULT timezone('utc'::text, now()),
            updated_at TIMESTAMP WITH TIME ZONE DEFAULT timezone('utc'::text, now())
        );
    END IF;
END $$;

-- Grant permissions for application_questions_2
GRANT ALL ON public.application_questions_2 TO authenticated;
GRANT ALL ON public.application_questions_2 TO service_role;

-- 3. Drop and recreate application_details view to include user_email
-- First, let's check what columns actually exist in applications table
DROP VIEW IF EXISTS public.application_details CASCADE;
CREATE VIEW public.application_details AS
SELECT 
    a.*,
    p.email as user_email
FROM 
    public.applications a
    LEFT JOIN public.profiles p ON a.user_id = p.id;

-- Grant permissions
GRANT SELECT ON public.application_details TO authenticated;
GRANT SELECT ON public.application_details TO service_role;
GRANT UPDATE ON public.applications TO authenticated;
GRANT UPDATE ON public.applications TO service_role;

-- Refresh schema cache
NOTIFY pgrst, 'reload schema';