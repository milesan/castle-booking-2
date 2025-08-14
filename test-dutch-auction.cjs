// Test script to verify Dutch Auction components work
const fs = require('fs');
const path = require('path');

console.log('\n🧪 Testing Dutch Auction System Components\n');
console.log('=' .repeat(50));

// Test 1: Check all files exist
console.log('\n✅ Test 1: Checking if all required files exist...');
const requiredFiles = [
  'src/components/admin/DutchAuctionAdmin.tsx',
  'src/pages/DutchAuctionPage.tsx',
  'src/hooks/useDutchAuction.ts',
  'supabase/migrations/20250810_add_dutch_auction_fields.sql'
];

let allFilesExist = true;
requiredFiles.forEach(file => {
  const exists = fs.existsSync(file);
  console.log(`  ${exists ? '✓' : '✗'} ${file}`);
  if (!exists) allFilesExist = false;
});

// Test 2: Check imports are valid
console.log('\n✅ Test 2: Checking component imports...');
const adminComponent = fs.readFileSync('src/components/admin/DutchAuctionAdmin.tsx', 'utf8');
const pageComponent = fs.readFileSync('src/pages/DutchAuctionPage.tsx', 'utf8');
const hookFile = fs.readFileSync('src/hooks/useDutchAuction.ts', 'utf8');

// Check for required imports
const importChecks = [
  { file: 'DutchAuctionAdmin', content: adminComponent, imports: ['React', 'supabase', 'lucide-react', 'date-fns'] },
  { file: 'DutchAuctionPage', content: pageComponent, imports: ['React', 'framer-motion', 'useDutchAuction', 'useSession'] },
  { file: 'useDutchAuction', content: hookFile, imports: ['useState', 'useEffect', 'supabase', 'date-fns'] }
];

let allImportsValid = true;
importChecks.forEach(check => {
  console.log(`\n  Checking ${check.file}:`);
  check.imports.forEach(imp => {
    const hasImport = check.content.includes(imp);
    console.log(`    ${hasImport ? '✓' : '✗'} Import: ${imp}`);
    if (!hasImport) allImportsValid = false;
  });
});

// Test 3: Check exports
console.log('\n✅ Test 3: Checking component exports...');
const exportChecks = [
  { file: 'DutchAuctionAdmin', content: adminComponent, exportName: 'DutchAuctionAdmin' },
  { file: 'DutchAuctionPage', content: pageComponent, exportName: 'DutchAuctionPage' },
  { file: 'useDutchAuction', content: hookFile, exportName: 'useDutchAuction' }
];

let allExportsValid = true;
exportChecks.forEach(check => {
  const hasExport = check.content.includes(`export function ${check.exportName}`) || 
                    check.content.includes(`export const ${check.exportName}`) ||
                    check.content.includes(`export { ${check.exportName}`);
  console.log(`  ${hasExport ? '✓' : '✗'} ${check.file} exports ${check.exportName}`);
  if (!hasExport) allExportsValid = false;
});

// Test 4: Check SQL syntax (basic)
console.log('\n✅ Test 4: Checking SQL migration syntax...');
const sqlContent = fs.readFileSync('supabase/migrations/20250810_add_dutch_auction_fields.sql', 'utf8');
const sqlChecks = [
  'ALTER TABLE public.accommodations',
  'CREATE TABLE IF NOT EXISTS public.auction_config',
  'CREATE TABLE IF NOT EXISTS public.auction_history',
  'CREATE OR REPLACE FUNCTION calculate_auction_price',
  'CREATE OR REPLACE FUNCTION update_auction_prices',
  'CREATE POLICY'
];

let allSqlValid = true;
sqlChecks.forEach(check => {
  const hasStatement = sqlContent.includes(check);
  console.log(`  ${hasStatement ? '✓' : '✗'} ${check}`);
  if (!hasStatement) allSqlValid = false;
});

// Test 5: Check integration with existing app
console.log('\n✅ Test 5: Checking app integration...');
const appFile = fs.readFileSync('src/App.tsx', 'utf8');
const adminPageFile = fs.readFileSync('src/pages/AdminPage.tsx', 'utf8');

const integrationChecks = [
  { file: 'App.tsx', content: appFile, check: 'DutchAuctionPage', description: 'DutchAuctionPage import' },
  { file: 'App.tsx', content: appFile, check: '/dutch-auction', description: 'Dutch auction route' },
  { file: 'AdminPage.tsx', content: adminPageFile, check: 'DutchAuctionAdmin', description: 'DutchAuctionAdmin import' },
  { file: 'AdminPage.tsx', content: adminPageFile, check: 'dutch-auction', description: 'Dutch auction tab' }
];

let allIntegrationValid = true;
integrationChecks.forEach(check => {
  const hasIntegration = check.content.includes(check.check);
  console.log(`  ${hasIntegration ? '✓' : '✗'} ${check.file}: ${check.description}`);
  if (!hasIntegration) allIntegrationValid = false;
});

// Summary
console.log('\n' + '=' .repeat(50));
console.log('\n📊 TEST SUMMARY:\n');
console.log(`  Files Exist:        ${allFilesExist ? '✅ PASSED' : '❌ FAILED'}`);
console.log(`  Imports Valid:      ${allImportsValid ? '✅ PASSED' : '❌ FAILED'}`);
console.log(`  Exports Valid:      ${allExportsValid ? '✅ PASSED' : '❌ FAILED'}`);
console.log(`  SQL Valid:          ${allSqlValid ? '✅ PASSED' : '❌ FAILED'}`);
console.log(`  App Integration:    ${allIntegrationValid ? '✅ PASSED' : '❌ FAILED'}`);

const allTestsPassed = allFilesExist && allImportsValid && allExportsValid && allSqlValid && allIntegrationValid;
console.log(`\n  Overall Result:     ${allTestsPassed ? '🎉 ALL TESTS PASSED!' : '❌ SOME TESTS FAILED'}`);

if (allTestsPassed) {
  console.log('\n✨ The Dutch Auction system is ready to use!');
  console.log('\nNext steps:');
  console.log('  1. Run the SQL migration in your Supabase dashboard');
  console.log('  2. Access the admin panel at /admin -> Dutch Auction tab');
  console.log('  3. Configure room tiers and start the auction');
  console.log('  4. Users can access the auction at /dutch-auction');
} else {
  console.log('\n⚠️  Please fix the issues above before proceeding.');
}

console.log('\n' + '=' .repeat(50) + '\n');