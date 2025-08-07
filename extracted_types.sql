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
