import { chromium } from 'playwright';

(async () => {
  const browser = await chromium.launch({ headless: false });
  const page = await browser.newPage();
  
  // Listen to console logs
  page.on('console', msg => {
    console.log('BROWSER LOG:', msg.text());
  });
  
  // Navigate to the booking page
  await page.goto('http://localhost:3000/book2');
  
  // Wait for the page to load
  await page.waitForTimeout(5000);
  
  // Check if accommodations are visible
  const accommodations = await page.$$('.group');
  console.log(`Found ${accommodations.length} accommodation cards`);
  
  // Try to find and click on an image
  const images = await page.$$('img');
  console.log(`Found ${images.length} images on page`);
  
  // Click on the first accommodation image if it exists
  if (images.length > 0) {
    console.log('Attempting to click on first image...');
    
    // Get image info before clicking
    const imgSrc = await images[0].getAttribute('src');
    console.log('Image src:', imgSrc);
    
    // Check if image is clickable
    const isClickable = await images[0].isVisible();
    console.log('Image is visible:', isClickable);
    
    // Try clicking
    await images[0].click();
    console.log('Clicked on image');
    
    // Wait to see if gallery opens
    await page.waitForTimeout(2000);
    
    // Check if gallery opened
    const gallery = await page.$('.fixed.inset-0.z-\\[9999\\]');
    if (gallery) {
      console.log('Gallery opened successfully!');
    } else {
      console.log('Gallery did not open');
    }
  }
  
  await page.waitForTimeout(5000);
  await browser.close();
})();