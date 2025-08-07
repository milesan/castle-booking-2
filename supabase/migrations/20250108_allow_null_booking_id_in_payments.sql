-- Allow NULL booking_id in payments table for pending payments
-- This is needed because we create a payment record before the booking exists

ALTER TABLE public.payments 
ALTER COLUMN booking_id DROP NOT NULL;

-- Add comment to explain why booking_id can be NULL
COMMENT ON COLUMN public.payments.booking_id IS 'Reference to the booking. Can be NULL for pending payments that are created before the booking.';