import { createClient } from '@supabase/supabase-js';

const supabaseUrl = 'https://ywsbmarhoyxercqatbfy.supabase.co';
const supabaseKey = 'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6Inl3c2JtYXJob3l4ZXJjcWF0YmZ5Iiwicm9sZSI6ImFub24iLCJpYXQiOjE3NTQ1MDA2MDgsImV4cCI6MjA3MDA3NjYwOH0.s9yyutya3lLOhHvvjqPDqvg7v7y2e72KPTFp4ZICiQg';

const supabase = createClient(supabaseUrl, supabaseKey);

async function verify() {
  const { data } = await supabase
    .from('auction_config')
    .select('auction_start_time, auction_end_time')
    .single();

  console.log('Raw start time:', data.auction_start_time);
  console.log('Raw end time:', data.auction_end_time);
  console.log('Start date:', new Date(data.auction_start_time).toISOString());
  console.log('End date:', new Date(data.auction_end_time).toISOString());
}

verify();