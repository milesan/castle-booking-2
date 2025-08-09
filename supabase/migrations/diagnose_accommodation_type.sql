-- Diagnostic script to check current accommodation_type enum state

-- 1. Check if accommodation_type exists and its values
SELECT 
    n.nspname as schema,
    t.typname as type_name,
    string_agg(e.enumlabel::text, ', ' ORDER BY e.enumsortorder) as enum_values
FROM pg_type t 
JOIN pg_enum e ON t.oid = e.enumtypid  
JOIN pg_namespace n ON n.oid = t.typnamespace
WHERE t.typname = 'accommodation_type'
GROUP BY n.nspname, t.typname;

-- 2. Check current columns in accommodations table
SELECT 
    column_name, 
    data_type,
    udt_name,
    is_nullable,
    column_default
FROM information_schema.columns 
WHERE table_schema = 'public' 
AND table_name = 'accommodations'
ORDER BY ordinal_position;

-- 3. Check if type column exists and what it references
SELECT 
    a.attname as column_name,
    t.typname as type_name,
    n.nspname as type_schema
FROM pg_attribute a
JOIN pg_class c ON a.attrelid = c.oid
JOIN pg_type t ON a.atttypid = t.oid
JOIN pg_namespace n ON t.typnamespace = n.oid
WHERE c.relname = 'accommodations'
AND a.attname = 'type'
AND NOT a.attisdropped;

-- 4. Show all enum types in the database
SELECT 
    n.nspname as schema,
    t.typname as enum_name,
    string_agg(e.enumlabel::text, ', ' ORDER BY e.enumsortorder) as values
FROM pg_type t 
JOIN pg_enum e ON t.oid = e.enumtypid  
JOIN pg_namespace n ON n.oid = t.typnamespace
WHERE t.typtype = 'e'
GROUP BY n.nspname, t.typname
ORDER BY n.nspname, t.typname;