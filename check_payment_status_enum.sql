-- Check payment_status enum values
SELECT unnest(enum_range(NULL::payment_status)) as payment_status_values;

-- Also check the columns in payments table
SELECT 
    column_name,
    data_type,
    is_nullable,
    column_default
FROM 
    information_schema.columns
WHERE 
    table_schema = 'public' 
    AND table_name = 'payments'
ORDER BY 
    ordinal_position;
