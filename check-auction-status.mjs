import { createClient } from '@supabase/supabase-js';

const supabaseUrl = 'https://ywsbmarhoyxercqatbfy.supabase.co';
const supabaseKey = 'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6Inl3c2JtYXJob3l4ZXJjcWF0YmZ5Iiwicm9sZSI6ImFub24iLCJpYXQiOjE3NTQ1MDA2MDgsImV4cCI6MjA3MDA3NjYwOH0.s9yyutya3lLOhHvvjqPDqvg7v7y2e72KPTFp4ZICiQg';

const supabase = createClient(supabaseUrl, supabaseKey);

async function checkStatus() {
  console.log('Checking auction status...\n');

  // Check auction_config table
  const { data: configs, error: configError } = await supabase
    .from('auction_config')
    .select('*');

  console.log('Auction configs:', configs);
  if (configError) console.log('Config error:', configError);

  // Check some accommodations
  const { data: rooms, error: roomsError } = await supabase
    .from('accommodations')
    .select('id, title, auction_tier, is_in_auction, auction_start_price, auction_floor_price')
    .eq('is_in_auction', true)
    .limit(5);

  console.log('\nSample auction rooms:', rooms);
  if (roomsError) console.log('Rooms error:', roomsError);
}

checkStatus();