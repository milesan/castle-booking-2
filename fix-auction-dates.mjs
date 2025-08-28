import { createClient } from '@supabase/supabase-js';

const supabaseUrl = 'https://ywsbmarhoyxercqatbfy.supabase.co';
const supabaseKey = 'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6Inl3c2JtYXJob3l4ZXJjcWF0YmZ5Iiwicm9sZSI6ImFub24iLCJpYXQiOjE3NTQ1MDA2MDgsImV4cCI6MjA3MDA3NjYwOH0.s9yyutya3lLOhHvvjqPDqvg7v7y2e72KPTFp4ZICiQg';

const supabase = createClient(supabaseUrl, supabaseKey);

async function fixDates() {
  console.log('Fixing auction dates to August 15, 2025...');
  
  const { data, error } = await supabase
    .from('auction_config')
    .update({
      auction_start_time: '2025-08-15T00:00:00Z',
      auction_end_time: '2025-09-14T23:59:59Z'
    })
    .eq('id', 'fd02b8f0-daa8-466b-b788-3f42f97d843f');

  if (error) {
    console.error('Error:', error);
  } else {
    console.log('✓ Dates updated successfully');
    
    // Verify the update
    const { data: verify } = await supabase
      .from('auction_config')
      .select('auction_start_time, auction_end_time')
      .single();
    
    console.log('New start date:', new Date(verify.auction_start_time).toLocaleDateString());
    console.log('New end date:', new Date(verify.auction_end_time).toLocaleDateString());
  }
}

fixDates();