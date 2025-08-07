-- Rename bed_size column to additional_info for more flexible usage
ALTER TABLE public.accommodations 
RENAME COLUMN bed_size TO additional_info;

-- Update the comment to reflect new purpose
COMMENT ON COLUMN public.accommodations.additional_info IS 'Additional information about the accommodation (e.g., bed details, bathroom location, amenities)';