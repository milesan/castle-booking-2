-- This script restores the schema from the backup
-- Run this in the Supabase SQL editor

-- First, create custom types
CREATE TYPE public.accommodation_type AS ENUM (
    'cabin',
    'camping',
    'dorm'
);

CREATE TYPE public.booking_status AS ENUM (
    'pending',
    'confirmed',
    'cancelled',
    'completed'
);

CREATE TYPE public.application_question_type AS ENUM (
    'text',
    'textarea',
    'radio',
    'checkbox',
    'date'
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

-- Now we'll add the tables
-- You'll need to run the backup file after this to get all tables