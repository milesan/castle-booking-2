-- Check what columns actually exist in the tables
SELECT 
    table_name,
    column_name,
    data_type
FROM 
    information_schema.columns
WHERE 
    table_schema = 'public' 
    AND table_name IN ('payments', 'applications', 'application_questions', 'application_questions_2')
ORDER BY 
    table_name, ordinal_position;