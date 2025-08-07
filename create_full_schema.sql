-- Complete Castle Booking Database Schema
-- Run this in Supabase SQL Editor

-- ============================================
-- 1. CREATE CUSTOM TYPES
-- ============================================

-- Drop types if they exist (for clean slate)
DROP TYPE IF EXISTS public.accommodation_type CASCADE;
DROP TYPE IF EXISTS public.accommodation_item_type CASCADE;
DROP TYPE IF EXISTS public.accommodation_item_size CASCADE;
DROP TYPE IF EXISTS public.accommodation_zone CASCADE;
DROP TYPE IF EXISTS public.booking_status CASCADE;
DROP TYPE IF EXISTS public.application_question_type CASCADE;
DROP TYPE IF EXISTS public.payment_status CASCADE;
DROP TYPE IF EXISTS public.payment_type CASCADE;
DROP TYPE IF EXISTS public.user_status_enum CASCADE;
DROP TYPE IF EXISTS public.discount_types CASCADE;
DROP TYPE IF EXISTS public.week_status CASCADE;

-- Create types
CREATE TYPE public.accommodation_type AS ENUM (
    'cabin',
    'camping',
    'dorm'
);

CREATE TYPE public.accommodation_item_type AS ENUM (
    'room',
    'mattress',
    'tent_spot'
);

CREATE TYPE public.accommodation_item_size AS ENUM (
    'single',
    'couple'
);

CREATE TYPE public.accommodation_zone AS ENUM (
    'forest',
    'lawn'
);

CREATE TYPE public.booking_status AS ENUM (
    'pending',
    'confirmed',
    'cancelled',
    'completed',
    'hold'
);

CREATE TYPE public.application_question_type AS ENUM (
    'text',
    'textarea',
    'radio',
    'checkbox',
    'date',
    'number',
    'email',
    'tel',
    'url',
    'file',
    'select',
    'multiselect'
);

CREATE TYPE public.payment_status AS ENUM (
    'pending',
    'completed',
    'failed',
    'refunded'
);

CREATE TYPE public.payment_type AS ENUM (
    'stripe',
    'manual',
    'comp'
);

CREATE TYPE public.user_status_enum AS ENUM (
    'pending',
    'approved',
    'rejected'
);

CREATE TYPE public.discount_types AS ENUM (
    'percentage',
    'fixed'
);

CREATE TYPE public.week_status AS ENUM (
    'available',
    'booked',
    'hold',
    'unavailable'
);

-- ============================================
-- 2. CREATE TABLES
-- ============================================

-- Profiles table (extends auth.users)
CREATE TABLE IF NOT EXISTS public.profiles (
    id uuid PRIMARY KEY REFERENCES auth.users(id) ON DELETE CASCADE,
    email text,
    first_name text,
    last_name text,
    phone text,
    created_at timestamptz DEFAULT now(),
    updated_at timestamptz DEFAULT now(),
    is_admin boolean DEFAULT false,
    avatar_url text,
    user_status public.user_status_enum DEFAULT 'pending',
    stripe_customer_id text,
    total_credits numeric DEFAULT 0,
    used_credits numeric DEFAULT 0
);

-- Accommodations table
CREATE TABLE IF NOT EXISTS public.accommodations (
    id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
    title text NOT NULL,
    base_price real NOT NULL CHECK (base_price >= 0),
    type public.accommodation_type NOT NULL,
    inventory integer CHECK (inventory >= 0),
    has_wifi boolean DEFAULT false,
    has_electricity boolean DEFAULT false,
    image_url text,
    is_unlimited boolean DEFAULT false,
    bed_size text,
    bathroom_type text DEFAULT 'none',
    bathrooms numeric DEFAULT 0,
    capacity integer DEFAULT 1 NOT NULL,
    created_at timestamptz DEFAULT now(),
    updated_at timestamptz DEFAULT now()
);

-- Accommodation items (specific rooms/spots)
CREATE TABLE IF NOT EXISTS public.accommodation_items (
    id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
    accommodation_id uuid REFERENCES public.accommodations(id) ON DELETE CASCADE,
    name text NOT NULL,
    type public.accommodation_item_type DEFAULT 'room',
    size public.accommodation_item_size DEFAULT 'single',
    zone public.accommodation_zone,
    is_available boolean DEFAULT true,
    notes text,
    created_at timestamptz DEFAULT now(),
    updated_at timestamptz DEFAULT now()
);

-- Bookings table
CREATE TABLE IF NOT EXISTS public.bookings (
    id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
    user_id uuid REFERENCES auth.users(id) ON DELETE CASCADE,
    accommodation_id uuid REFERENCES public.accommodations(id),
    accommodation_item_id uuid REFERENCES public.accommodation_items(id),
    check_in date NOT NULL,
    check_out date NOT NULL,
    total_price numeric NOT NULL,
    status public.booking_status DEFAULT 'pending',
    created_at timestamptz DEFAULT now(),
    updated_at timestamptz DEFAULT now(),
    nights integer GENERATED ALWAYS AS (check_out - check_in) STORED,
    base_price numeric,
    discount_amount numeric DEFAULT 0,
    credits_applied numeric DEFAULT 0,
    final_price numeric,
    stripe_payment_intent_id text,
    stripe_payment_status text,
    confirmation_email_sent boolean DEFAULT false,
    notes text,
    discount_code text,
    flexible_check_in boolean DEFAULT false,
    flexible_date date,
    arrival_reminder_sent_at timestamptz,
    hold_expires_at timestamptz,
    CONSTRAINT check_dates CHECK (check_out > check_in)
);

-- Applications table
CREATE TABLE IF NOT EXISTS public.applications (
    id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
    user_id uuid REFERENCES auth.users(id) ON DELETE CASCADE,
    status public.user_status_enum DEFAULT 'pending',
    submitted_at timestamptz DEFAULT now(),
    reviewed_at timestamptz,
    reviewed_by uuid REFERENCES auth.users(id),
    reviewer_notes text,
    data jsonb DEFAULT '{}'::jsonb,
    created_at timestamptz DEFAULT now(),
    updated_at timestamptz DEFAULT now()
);

-- Application questions
CREATE TABLE IF NOT EXISTS public.application_questions (
    id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
    question text NOT NULL,
    type public.application_question_type DEFAULT 'text',
    options jsonb,
    required boolean DEFAULT false,
    order_number integer,
    category text,
    placeholder text,
    help_text text,
    validation jsonb,
    created_at timestamptz DEFAULT now(),
    updated_at timestamptz DEFAULT now()
);

-- Linked applications (for group applications)
CREATE TABLE IF NOT EXISTS public.linked_applications (
    id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
    primary_application_id uuid REFERENCES public.applications(id) ON DELETE CASCADE,
    email text NOT NULL,
    first_name text,
    last_name text,
    status public.user_status_enum DEFAULT 'pending',
    created_at timestamptz DEFAULT now()
);

-- Payments table
CREATE TABLE IF NOT EXISTS public.payments (
    id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
    booking_id uuid REFERENCES public.bookings(id) ON DELETE CASCADE,
    user_id uuid REFERENCES auth.users(id),
    amount numeric NOT NULL,
    status public.payment_status DEFAULT 'pending',
    type public.payment_type DEFAULT 'stripe',
    stripe_payment_intent_id text,
    stripe_charge_id text,
    metadata jsonb DEFAULT '{}'::jsonb,
    created_at timestamptz DEFAULT now(),
    updated_at timestamptz DEFAULT now()
);

-- Discount codes
CREATE TABLE IF NOT EXISTS public.discount_codes (
    id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
    code text UNIQUE NOT NULL,
    type public.discount_types NOT NULL,
    value numeric NOT NULL,
    valid_from timestamptz DEFAULT now(),
    valid_until timestamptz,
    max_uses integer,
    uses_count integer DEFAULT 0,
    is_active boolean DEFAULT true,
    created_at timestamptz DEFAULT now(),
    updated_at timestamptz DEFAULT now()
);

-- Settings table
CREATE TABLE IF NOT EXISTS public.settings (
    id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
    key text UNIQUE NOT NULL,
    value jsonb NOT NULL,
    description text,
    created_at timestamptz DEFAULT now(),
    updated_at timestamptz DEFAULT now()
);

-- Arrival rules
CREATE TABLE IF NOT EXISTS public.arrival_rules (
    id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
    day_of_week integer NOT NULL CHECK (day_of_week >= 0 AND day_of_week <= 6),
    arrival_time time NOT NULL,
    created_at timestamptz DEFAULT now()
);

-- Day rules
CREATE TABLE IF NOT EXISTS public.day_rules (
    id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
    accommodation_id uuid REFERENCES public.accommodations(id) ON DELETE CASCADE,
    date date NOT NULL,
    is_available boolean DEFAULT true,
    check_in_allowed boolean DEFAULT true,
    check_out_allowed boolean DEFAULT true,
    price_override numeric,
    notes text,
    created_at timestamptz DEFAULT now(),
    updated_at timestamptz DEFAULT now(),
    UNIQUE(accommodation_id, date)
);

-- Scheduling rules
CREATE TABLE IF NOT EXISTS public.scheduling_rules (
    id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
    title text NOT NULL,
    start_date date NOT NULL,
    end_date date NOT NULL,
    check_in_day integer,
    check_out_day integer,
    min_nights integer DEFAULT 1,
    max_nights integer,
    price_override numeric,
    is_active boolean DEFAULT true,
    created_at timestamptz DEFAULT now(),
    updated_at timestamptz DEFAULT now(),
    CONSTRAINT valid_date_range CHECK (end_date >= start_date),
    CONSTRAINT valid_days CHECK (
        (check_in_day IS NULL OR (check_in_day >= 0 AND check_in_day <= 6)) AND
        (check_out_day IS NULL OR (check_out_day >= 0 AND check_out_day <= 6))
    )
);

-- Credits transactions
CREATE TABLE IF NOT EXISTS public.credit_transactions (
    id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
    user_id uuid REFERENCES auth.users(id) ON DELETE CASCADE,
    amount numeric NOT NULL,
    type text NOT NULL, -- 'added', 'used', 'refunded'
    description text,
    booking_id uuid REFERENCES public.bookings(id),
    created_at timestamptz DEFAULT now()
);

-- ============================================
-- 3. CREATE INDEXES
-- ============================================

CREATE INDEX IF NOT EXISTS idx_bookings_user_id ON public.bookings(user_id);
CREATE INDEX IF NOT EXISTS idx_bookings_accommodation_id ON public.bookings(accommodation_id);
CREATE INDEX IF NOT EXISTS idx_bookings_check_in ON public.bookings(check_in);
CREATE INDEX IF NOT EXISTS idx_bookings_check_out ON public.bookings(check_out);
CREATE INDEX IF NOT EXISTS idx_bookings_status ON public.bookings(status);
CREATE INDEX IF NOT EXISTS idx_applications_user_id ON public.applications(user_id);
CREATE INDEX IF NOT EXISTS idx_applications_status ON public.applications(status);
CREATE INDEX IF NOT EXISTS idx_payments_booking_id ON public.payments(booking_id);
CREATE INDEX IF NOT EXISTS idx_payments_user_id ON public.payments(user_id);
CREATE INDEX IF NOT EXISTS idx_credit_transactions_user_id ON public.credit_transactions(user_id);

-- ============================================
-- 4. ENABLE ROW LEVEL SECURITY
-- ============================================

ALTER TABLE public.profiles ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.accommodations ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.accommodation_items ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.bookings ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.applications ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.application_questions ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.linked_applications ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.payments ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.discount_codes ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.settings ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.arrival_rules ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.day_rules ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.scheduling_rules ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.credit_transactions ENABLE ROW LEVEL SECURITY;

-- ============================================
-- 5. CREATE RLS POLICIES
-- ============================================

-- Profiles policies
CREATE POLICY "Public profiles are viewable by everyone" ON public.profiles
    FOR SELECT USING (true);

CREATE POLICY "Users can update own profile" ON public.profiles
    FOR UPDATE USING (auth.uid() = id);

-- Accommodations policies
CREATE POLICY "Accommodations are viewable by everyone" ON public.accommodations
    FOR SELECT USING (true);

-- Bookings policies
CREATE POLICY "Users can view own bookings" ON public.bookings
    FOR SELECT USING (auth.uid() = user_id);

CREATE POLICY "Users can create own bookings" ON public.bookings
    FOR INSERT WITH CHECK (auth.uid() = user_id);

CREATE POLICY "Users can update own bookings" ON public.bookings
    FOR UPDATE USING (auth.uid() = user_id);

-- Applications policies
CREATE POLICY "Users can view own applications" ON public.applications
    FOR SELECT USING (auth.uid() = user_id);

CREATE POLICY "Users can create own applications" ON public.applications
    FOR INSERT WITH CHECK (auth.uid() = user_id);

-- Application questions policies
CREATE POLICY "Application questions are viewable by everyone" ON public.application_questions
    FOR SELECT USING (true);

-- Settings policies
CREATE POLICY "Settings are viewable by everyone" ON public.settings
    FOR SELECT USING (true);

-- Arrival rules policies
CREATE POLICY "Arrival rules are viewable by everyone" ON public.arrival_rules
    FOR SELECT USING (true);

-- Scheduling rules policies  
CREATE POLICY "Scheduling rules are viewable by everyone" ON public.scheduling_rules
    FOR SELECT USING (true);

-- ============================================
-- 6. CREATE FUNCTIONS
-- ============================================

-- Function to handle new user creation
CREATE OR REPLACE FUNCTION public.handle_new_user()
RETURNS trigger AS $$
BEGIN
    INSERT INTO public.profiles (id, email, created_at, updated_at)
    VALUES (
        NEW.id,
        NEW.email,
        NEW.created_at,
        NEW.updated_at
    );
    RETURN NEW;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- Function to check booking availability
CREATE OR REPLACE FUNCTION public.check_availability(
    p_accommodation_id uuid,
    p_check_in date,
    p_check_out date
)
RETURNS boolean AS $$
DECLARE
    v_available boolean;
BEGIN
    SELECT NOT EXISTS (
        SELECT 1 FROM public.bookings
        WHERE accommodation_id = p_accommodation_id
        AND status IN ('confirmed', 'hold')
        AND (
            (check_in <= p_check_in AND check_out > p_check_in) OR
            (check_in < p_check_out AND check_out >= p_check_out) OR
            (check_in >= p_check_in AND check_out <= p_check_out)
        )
    ) INTO v_available;
    
    RETURN v_available;
END;
$$ LANGUAGE plpgsql;

-- Function to calculate booking price
CREATE OR REPLACE FUNCTION public.calculate_booking_price(
    p_accommodation_id uuid,
    p_check_in date,
    p_check_out date
)
RETURNS numeric AS $$
DECLARE
    v_base_price numeric;
    v_nights integer;
    v_total_price numeric;
BEGIN
    -- Get base price
    SELECT base_price INTO v_base_price
    FROM public.accommodations
    WHERE id = p_accommodation_id;
    
    -- Calculate nights
    v_nights := p_check_out - p_check_in;
    
    -- Calculate total
    v_total_price := v_base_price * v_nights;
    
    RETURN v_total_price;
END;
$$ LANGUAGE plpgsql;

-- ============================================
-- 7. CREATE TRIGGERS
-- ============================================

-- Trigger for new user creation
CREATE TRIGGER on_auth_user_created
    AFTER INSERT ON auth.users
    FOR EACH ROW
    EXECUTE FUNCTION public.handle_new_user();

-- Trigger to update updated_at timestamp
CREATE OR REPLACE FUNCTION public.update_updated_at_column()
RETURNS trigger AS $$
BEGIN
    NEW.updated_at = now();
    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

-- Add updated_at triggers to all tables
CREATE TRIGGER update_profiles_updated_at BEFORE UPDATE ON public.profiles
    FOR EACH ROW EXECUTE FUNCTION public.update_updated_at_column();

CREATE TRIGGER update_accommodations_updated_at BEFORE UPDATE ON public.accommodations
    FOR EACH ROW EXECUTE FUNCTION public.update_updated_at_column();

CREATE TRIGGER update_bookings_updated_at BEFORE UPDATE ON public.bookings
    FOR EACH ROW EXECUTE FUNCTION public.update_updated_at_column();

CREATE TRIGGER update_applications_updated_at BEFORE UPDATE ON public.applications
    FOR EACH ROW EXECUTE FUNCTION public.update_updated_at_column();

-- ============================================
-- 8. GRANT PERMISSIONS
-- ============================================

GRANT USAGE ON SCHEMA public TO anon, authenticated;
GRANT ALL ON ALL TABLES IN SCHEMA public TO anon, authenticated;
GRANT ALL ON ALL SEQUENCES IN SCHEMA public TO anon, authenticated;
GRANT ALL ON ALL FUNCTIONS IN SCHEMA public TO anon, authenticated;

-- ============================================
-- 9. INSERT DEFAULT DATA
-- ============================================

-- Insert default settings
INSERT INTO public.settings (key, value, description) VALUES
    ('max_booking_days', '30', 'Maximum days allowed for a booking'),
    ('min_booking_days', '1', 'Minimum days required for a booking'),
    ('booking_buffer_hours', '24', 'Hours before check-in when booking closes')
ON CONFLICT (key) DO NOTHING;

-- Insert default arrival rules (example: arrivals at 3 PM every day)
INSERT INTO public.arrival_rules (day_of_week, arrival_time) VALUES
    (0, '15:00'),
    (1, '15:00'),
    (2, '15:00'),
    (3, '15:00'),
    (4, '15:00'),
    (5, '15:00'),
    (6, '15:00')
ON CONFLICT DO NOTHING;

-- ============================================
-- DONE! Your database schema is ready.
-- ============================================