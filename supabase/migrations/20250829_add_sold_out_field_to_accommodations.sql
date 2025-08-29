-- Add sold_out field to accommodations table
ALTER TABLE accommodations 
ADD COLUMN IF NOT EXISTS sold_out BOOLEAN DEFAULT FALSE;

-- Add comment for documentation
COMMENT ON COLUMN accommodations.sold_out IS 'Indicates if the accommodation is sold out and should not be available for booking';