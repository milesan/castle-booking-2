CREATE TYPE public.accommodation_item_size AS ENUM (
    '2',
    '3',
    '4',
    '5',
    '6',
    'tent',
    'van'
);
CREATE TYPE public.accommodation_item_type AS ENUM (
    'BT',
    'PT',
    'TP',
    'VC',
    'TC'
);
CREATE TYPE public.accommodation_type AS ENUM (
    'room',
    'dorm',
    'cabin',
    'tent',
    'parking',
    'addon',
    'test'
);
CREATE TYPE public.accommodation_zone AS ENUM (
    'T',
    'G',
    'C',
    'M',
    'N',
    'U',
    'L',
    'P'
);
CREATE TYPE public.application_question_type AS ENUM (
    'text',
    'radio',
    'date',
    'email',
    'tel',
    'file',
    'textarea',
    'password',
    'checkbox',
    'markdown_text',
    'arrival_date_selector'
);
CREATE TYPE public.booking_status AS ENUM (
    'pending',
    'confirmed',
    'cancelled'
);
CREATE TYPE public.discount_types AS ENUM (
    'total',
    'accommodation',
    'food_facilities'
);
CREATE TYPE public.payment_status AS ENUM (
    'pending',
    'paid',
    'failed',
    'refunded'
);
CREATE TYPE public.payment_type AS ENUM (
    'initial',
    'extension',
    'refund'
);
CREATE TYPE public.user_status_enum AS ENUM (
    'no_user',
    'in_application_form',
    'application_sent_pending',
    'application_sent_rejected',
    'application_approved',
    'whitelisted',
    'admin'
);
CREATE TYPE public.week_status AS ENUM (
    'visible',
    'hidden',
    'deleted',
    'default'
);
CREATE TYPE public.week_status2 AS ENUM (
    'visible',
    'hidden',
    'deleted'
);
CREATE TABLE public._deprecated_user_status (
    user_id uuid NOT NULL,
    status public.user_status_enum NOT NULL,
    welcome_screen_seen boolean DEFAULT false,
    whitelist_signup_completed boolean DEFAULT false,
    is_super_admin boolean DEFAULT false,
    updated_at timestamp with time zone DEFAULT now()
);
CREATE TABLE public.acceptance_tokens (
    id uuid DEFAULT gen_random_uuid() NOT NULL,
    application_id uuid NOT NULL,
    token text NOT NULL,
    created_at timestamp with time zone DEFAULT now() NOT NULL,
    expires_at timestamp with time zone NOT NULL,
    used_at timestamp with time zone
);
CREATE TABLE public.accommodation_images (
    id uuid DEFAULT gen_random_uuid() NOT NULL,
    accommodation_id uuid NOT NULL,
    image_url text NOT NULL,
    display_order integer DEFAULT 0 NOT NULL,
    is_primary boolean DEFAULT false NOT NULL,
    created_at timestamp with time zone DEFAULT now(),
    updated_at timestamp with time zone DEFAULT now()
);
CREATE TABLE public.accommodation_items (
    id uuid DEFAULT gen_random_uuid() NOT NULL,
    accommodation_id uuid NOT NULL,
    zone text,
    type text NOT NULL,
    size text NOT NULL,
    item_id integer NOT NULL,
    created_at timestamp with time zone DEFAULT timezone('utc'::text, now()) NOT NULL,
    updated_at timestamp with time zone DEFAULT timezone('utc'::text, now()) NOT NULL,
    CONSTRAINT positive_item_id CHECK ((item_id > 0))
);
CREATE TABLE public.accommodations (
    id uuid DEFAULT gen_random_uuid() NOT NULL,
    title text NOT NULL,
    base_price real NOT NULL,
    type public.accommodation_type NOT NULL,
    inventory integer,
    has_wifi boolean DEFAULT false NOT NULL,
    has_electricity boolean DEFAULT false NOT NULL,
    image_url text,
    is_unlimited boolean DEFAULT false NOT NULL,
    bed_size text,
    bathroom_type text DEFAULT 'none'::text,
    bathrooms numeric DEFAULT 0,
    capacity integer DEFAULT 1 NOT NULL,
    CONSTRAINT accommodations_base_price_check CHECK ((base_price >= (0)::double precision)),
    CONSTRAINT accommodations_inventory_check CHECK ((inventory >= 0))
);
CREATE TABLE public.applications (
    id uuid DEFAULT gen_random_uuid() NOT NULL,
    user_id uuid,
    status text DEFAULT 'pending'::text NOT NULL,
    created_at timestamp with time zone DEFAULT timezone('utc'::text, now()) NOT NULL,
    updated_at timestamp with time zone DEFAULT timezone('utc'::text, now()) NOT NULL,
    linked_application_id uuid,
    data jsonb,
    admin_verdicts jsonb DEFAULT '{}'::jsonb,
    final_action jsonb,
    tracking_status text DEFAULT 'new'::text,
    approved_on timestamp with time zone,
    subsidy boolean DEFAULT false,
    next_action text,
    on_sheet boolean DEFAULT false,
    notes text
);
CREATE TABLE public.bookings (
    id uuid DEFAULT gen_random_uuid() NOT NULL,
    user_id uuid,
    accommodation_id uuid NOT NULL,
    check_in date NOT NULL,
    check_out date NOT NULL,
    total_price numeric(10,2) NOT NULL,
    status public.booking_status DEFAULT 'pending'::public.booking_status NOT NULL,
    payment_intent_id text,
    created_at timestamp with time zone DEFAULT timezone('utc'::text, now()) NOT NULL,
    updated_at timestamp with time zone DEFAULT timezone('utc'::text, now()) NOT NULL,
    confirmation_email_sent boolean DEFAULT false,
    applied_discount_code text,
    discount_amount numeric(10,2),
    guest_email text,
    credits_used numeric(10,2) DEFAULT 0 NOT NULL,
    accommodation_price numeric(10,2),
    food_contribution numeric(10,2),
    seasonal_adjustment numeric(10,2),
    duration_discount_percent numeric(5,2),
    discount_code_percent numeric,
    discount_code_applies_to text,
    accommodation_price_paid numeric(10,2),
    seasonal_discount_percent numeric(5,2),
    accommodation_price_after_seasonal_duration numeric(10,2),
    subtotal_after_discount_code numeric(10,2),
    reminder_email_sent boolean DEFAULT false,
    admin_refund_amount numeric,
    accommodation_item_id uuid,
    CONSTRAINT bookings_credits_used_check CHECK ((credits_used >= (0)::numeric)),
    CONSTRAINT bookings_total_price_check CHECK ((total_price >= (0)::numeric)),
    CONSTRAINT check_discount_code_applies_to CHECK (((discount_code_applies_to = ANY (ARRAY['food_facilities'::text, 'total'::text, 'accommodation'::text])) OR (discount_code_applies_to IS NULL))),
    CONSTRAINT valid_dates CHECK ((check_out > check_in))
);
CREATE TABLE public.linked_applications (
    id uuid DEFAULT gen_random_uuid() NOT NULL,
    primary_application_id uuid,
    linked_name text NOT NULL,
    linked_email text NOT NULL,
    created_at timestamp with time zone DEFAULT timezone('utc'::text, now()) NOT NULL
);
CREATE TABLE public.profiles (
    id uuid NOT NULL,
    email text NOT NULL,
    created_at timestamp with time zone DEFAULT timezone('utc'::text, now()) NOT NULL,
    first_name text,
    last_name text,
    credits numeric(10,2) DEFAULT 0.00 NOT NULL
);
CREATE TABLE public.application_questions (
    id uuid DEFAULT gen_random_uuid() NOT NULL,
    order_number double precision NOT NULL,
    text text NOT NULL,
    type public.application_question_type NOT NULL,
    options jsonb,
    required boolean DEFAULT true,
    section text,
    created_at timestamp with time zone DEFAULT timezone('utc'::text, now()) NOT NULL,
    updated_at timestamp with time zone DEFAULT timezone('utc'::text, now()) NOT NULL,
    file_storage_bucket character varying,
    section_intro_markdown text,
    is_visible boolean DEFAULT true NOT NULL,
    depends_on_question_id uuid,
    depends_on_question_answer text,
    short_code text,
    CONSTRAINT check_order_number_range CHECK (((order_number >= (1000)::double precision) AND (order_number <= (100000)::double precision)))
);
CREATE TABLE public.application_questions_2 (
    id uuid DEFAULT gen_random_uuid() NOT NULL,
    order_number double precision NOT NULL,
    text text NOT NULL,
    type public.application_question_type NOT NULL,
    options jsonb,
    required boolean DEFAULT true,
    section text,
    created_at timestamp with time zone DEFAULT timezone('utc'::text, now()) NOT NULL,
    updated_at timestamp with time zone DEFAULT timezone('utc'::text, now()) NOT NULL,
    file_storage_bucket character varying,
    visibility_rules jsonb,
    CONSTRAINT check_order_number_range CHECK (((order_number >= (1000)::double precision) AND (order_number <= (100000)::double precision)))
);
CREATE TABLE public.application_questions_backup_20250221 (
    id uuid,
    order_number integer,
    text text,
    type text,
    options jsonb,
    required boolean,
    section text,
    created_at timestamp with time zone,
    updated_at timestamp with time zone,
    new_position bigint
);
CREATE TABLE public.applications_backup_20250221 (
    id uuid,
    user_id uuid,
    status text,
    created_at timestamp with time zone,
    updated_at timestamp with time zone,
    linked_application_id uuid,
    data jsonb
);
CREATE TABLE public.arrival_rules (
    id uuid DEFAULT gen_random_uuid() NOT NULL,
    arrival_day text NOT NULL,
    departure_day text NOT NULL,
    created_at timestamp with time zone DEFAULT timezone('utc'::text, now()) NOT NULL,
    updated_at timestamp with time zone DEFAULT timezone('utc'::text, now()) NOT NULL,
    CONSTRAINT different_days CHECK ((arrival_day <> departure_day)),
    CONSTRAINT valid_arrival_day CHECK ((arrival_day = ANY (ARRAY['monday'::text, 'tuesday'::text, 'wednesday'::text, 'thursday'::text, 'friday'::text, 'saturday'::text, 'sunday'::text]))),
    CONSTRAINT valid_departure_day CHECK ((departure_day = ANY (ARRAY['monday'::text, 'tuesday'::text, 'wednesday'::text, 'thursday'::text, 'friday'::text, 'saturday'::text, 'sunday'::text])))
);
CREATE TABLE public.bookings_duplicate (
    id uuid DEFAULT gen_random_uuid() NOT NULL,
    user_id uuid,
    accommodation_id uuid NOT NULL,
    check_in date NOT NULL,
    check_out date NOT NULL,
    total_price numeric(10,2) NOT NULL,
    status public.booking_status DEFAULT 'pending'::public.booking_status NOT NULL,
    payment_intent_id text,
    created_at timestamp with time zone DEFAULT timezone('utc'::text, now()) NOT NULL,
    updated_at timestamp with time zone DEFAULT timezone('utc'::text, now()) NOT NULL,
    confirmation_email_sent boolean DEFAULT false,
    applied_discount_code text,
    discount_amount numeric(10,2),
    guest_email text,
    credits_used numeric(10,2) DEFAULT 0 NOT NULL,
    accommodation_price numeric(10,2),
    food_contribution numeric(10,2),
    seasonal_adjustment numeric(10,2),
    duration_discount_percent numeric(5,2),
    discount_code_percent numeric(5,2),
    CONSTRAINT bookings_credits_used_check CHECK ((credits_used >= (0)::numeric)),
    CONSTRAINT bookings_total_price_check CHECK ((total_price >= (0)::numeric)),
    CONSTRAINT valid_dates CHECK ((check_out > check_in))
);
CREATE TABLE public.bug_reports (
    id uuid DEFAULT gen_random_uuid() NOT NULL,
    created_at timestamp with time zone DEFAULT now() NOT NULL,
    user_id uuid,
    description text NOT NULL,
    steps_to_reproduce text,
    page_url text,
    status text DEFAULT 'new'::text NOT NULL,
    image_urls text[]
);
CREATE TABLE public.calendar_config (
    id uuid DEFAULT extensions.uuid_generate_v4() NOT NULL,
    check_in_day smallint NOT NULL,
    check_out_day smallint NOT NULL,
    created_at timestamp with time zone DEFAULT now(),
    CONSTRAINT calendar_config_check_in_day_check CHECK (((check_in_day >= 0) AND (check_in_day <= 6))),
    CONSTRAINT calendar_config_check_out_day_check CHECK (((check_out_day >= 0) AND (check_out_day <= 6)))
);
CREATE TABLE public.credit_transactions (
    id uuid DEFAULT gen_random_uuid() NOT NULL,
    user_id uuid NOT NULL,
    admin_id uuid,
    booking_id uuid,
    amount numeric(10,2) NOT NULL,
    new_balance numeric(10,2) NOT NULL,
    transaction_type text NOT NULL,
    notes text,
    created_at timestamp with time zone DEFAULT timezone('utc'::text, now()) NOT NULL,
    CONSTRAINT credit_transactions_transaction_type_check CHECK ((transaction_type = ANY (ARRAY['admin_add'::text, 'admin_remove'::text, 'booking_payment'::text, 'booking_refund'::text, 'manual_refund'::text, 'promotional'::text])))
);
CREATE TABLE public.credits (
    id uuid DEFAULT gen_random_uuid() NOT NULL,
    user_id uuid NOT NULL,
    amount numeric(10,2) NOT NULL,
    description text,
    booking_id uuid,
    created_at timestamp with time zone DEFAULT timezone('utc'::text, now()) NOT NULL
);
CREATE TABLE public.day_rules (
    id uuid DEFAULT gen_random_uuid() NOT NULL,
    date date NOT NULL,
    is_arrival boolean DEFAULT false,
    is_departure boolean DEFAULT false,
    created_at timestamp with time zone DEFAULT timezone('utc'::text, now()) NOT NULL,
    updated_at timestamp with time zone DEFAULT timezone('utc'::text, now()) NOT NULL,
    not_arrival boolean DEFAULT false,
    not_departure boolean DEFAULT false,
    CONSTRAINT valid_rule CHECK (((NOT (is_arrival AND is_departure)) AND (NOT (is_arrival AND not_arrival)) AND (NOT (is_departure AND not_departure))))
);
CREATE TABLE public.deprecated_credits (
    id uuid DEFAULT gen_random_uuid() NOT NULL,
    user_id uuid NOT NULL,
    amount integer NOT NULL,
    description text NOT NULL,
    booking_id uuid,
    created_at timestamp with time zone DEFAULT timezone('utc'::text, now()) NOT NULL
);
CREATE TABLE public.discount_codes (
    id uuid DEFAULT gen_random_uuid() NOT NULL,
    code text NOT NULL,
    percentage_discount integer NOT NULL,
    description text,
    is_active boolean DEFAULT true NOT NULL,
    created_at timestamp with time zone DEFAULT now() NOT NULL,
    deactivated_at timestamp with time zone,
    created_by uuid DEFAULT auth.uid(),
    updated_at timestamp with time zone DEFAULT now() NOT NULL,
    applies_to public.discount_types DEFAULT 'total'::public.discount_types NOT NULL,
    CONSTRAINT discount_codes_percentage_discount_check CHECK (((percentage_discount > 0) AND (percentage_discount <= 100)))
);
CREATE TABLE public.flexible_checkins (
    id uuid DEFAULT gen_random_uuid() NOT NULL,
    week_customization_id uuid,
    allowed_checkin_date date NOT NULL,
    created_by uuid
);
CREATE TABLE public.payments (
    id uuid DEFAULT gen_random_uuid() NOT NULL,
    booking_id uuid,
    user_id uuid,
    start_date date NOT NULL,
    end_date date NOT NULL,
    amount_paid numeric(10,2) NOT NULL,
    breakdown_json jsonb,
    discount_code text,
    payment_type public.payment_type NOT NULL,
    stripe_payment_id text,
    created_at timestamp with time zone DEFAULT timezone('utc'::text, now()) NOT NULL,
    updated_at timestamp with time zone DEFAULT timezone('utc'::text, now()) NOT NULL,
    status public.payment_status DEFAULT 'pending'::public.payment_status NOT NULL
);
CREATE TABLE public.price_feedback (
    id uuid DEFAULT extensions.uuid_generate_v4() NOT NULL,
    created_at timestamp with time zone DEFAULT now() NOT NULL,
    user_id uuid,
    session_id text,
    selected_option text NOT NULL,
    booking_context jsonb,
    frontend_url text,
    notes text,
    CONSTRAINT price_feedback_selected_option_check CHECK ((selected_option = ANY (ARRAY['steep'::text, 'fair'::text, 'cheap'::text])))
);
CREATE TABLE public.saved_applications (
    id uuid DEFAULT gen_random_uuid() NOT NULL,
    user_id uuid NOT NULL,
    data jsonb NOT NULL,
    created_at timestamp with time zone DEFAULT timezone('utc'::text, now()) NOT NULL,
    updated_at timestamp with time zone DEFAULT timezone('utc'::text, now()) NOT NULL
);
CREATE TABLE public.scheduling_rules (
    id uuid DEFAULT gen_random_uuid() NOT NULL,
    start_date date NOT NULL,
    end_date date NOT NULL,
    arrival_day text,
    departure_day text,
    is_blocked boolean DEFAULT false,
    blocked_dates jsonb DEFAULT '[]'::jsonb,
    created_at timestamp with time zone DEFAULT timezone('utc'::text, now()) NOT NULL,
    updated_at timestamp with time zone DEFAULT timezone('utc'::text, now()) NOT NULL,
    CONSTRAINT valid_arrival_day CHECK (((arrival_day IS NULL) OR (arrival_day = ANY (ARRAY['monday'::text, 'tuesday'::text, 'wednesday'::text, 'thursday'::text, 'friday'::text, 'saturday'::text, 'sunday'::text])))),
    CONSTRAINT valid_dates CHECK ((start_date <= end_date)),
    CONSTRAINT valid_departure_day CHECK (((departure_day IS NULL) OR (departure_day = ANY (ARRAY['monday'::text, 'tuesday'::text, 'wednesday'::text, 'thursday'::text, 'friday'::text, 'saturday'::text, 'sunday'::text]))))
);
CREATE TABLE public.week_customizations (
    id uuid DEFAULT extensions.uuid_generate_v4() NOT NULL,
    start_date date NOT NULL,
    end_date date NOT NULL,
    name text,
    status public.week_status NOT NULL,
    created_by uuid,
    created_at timestamp with time zone DEFAULT now(),
    link text
);
CREATE TABLE public.whitelist (
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
CREATE TABLE public.whitelist_tokens (
    id uuid DEFAULT gen_random_uuid() NOT NULL,
    whitelist_id uuid NOT NULL,
    token text NOT NULL,
    created_at timestamp with time zone DEFAULT timezone('utc'::text, now()) NOT NULL,
    used_at timestamp with time zone
);
