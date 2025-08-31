import React, { useState, useEffect, useCallback, useRef, useMemo } from 'react';
import { motion } from 'framer-motion';
import { BedDouble, Bath, Percent, Info, Ear, ChevronLeft, ChevronRight, Users, Clock, ArrowUpDown, ArrowUp, ArrowDown } from 'lucide-react';
import clsx from 'clsx';
import type { Accommodation } from '../types';
import { Week } from '../types/calendar';
import { getSeasonalDiscount, getDurationDiscount, getSeasonBreakdown, calculateWeeklyAccommodationPrice } from '../utils/pricing';
import { useWeeklyAccommodations } from '../hooks/useWeeklyAccommodations';
import { addDays, isDate, isBefore } from 'date-fns';
import * as Tooltip from '@radix-ui/react-tooltip';
import * as Popover from '@radix-ui/react-popover';
import { calculateTotalNights, calculateDurationDiscountWeeks, normalizeToUTCDate } from '../utils/dates';
import { useSession } from '../hooks/useSession';
import { HoverClickPopover } from './HoverClickPopover';
import { useUserPermissions } from '../hooks/useUserPermissions';
import { usePendingBookings } from '../hooks/usePendingBookings';
// import { MasonryGallery } from './shared/MasonryGallery';
// import { FullScreenMasonry } from './FullScreenMasonry';
import { SimpleImageGallery } from './SimpleImageGallery';
import { SimpleThumbnailGallery } from './SimpleThumbnailGallery';
import { AccommodationInfoModal } from './AccommodationInfoModal';

// Local interface for accommodation images
interface AccommodationImage {
  id: string;
  accommodation_id: string;
  image_url: string;
  display_order: number;
  is_primary: boolean;
  created_at: string;
}

// Extend the Accommodation type to include images and property location
interface ExtendedAccommodation extends Accommodation {
  images?: AccommodationImage[];
  property_location?: string | null;
  property_section?: string | null;
  additional_info?: string | null;
  sold_out?: boolean;
}

interface Props {
  accommodations: ExtendedAccommodation[];
  selectedAccommodationId: string | null;
  onSelectAccommodation: (id: string) => void;
  isLoading?: boolean;
  selectedWeeks?: Week[];
  currentMonth?: Date;
  isDisabled?: boolean;
  displayWeeklyAccommodationPrice: (accommodationId: string) => { price: number | null; avgSeasonalDiscount: number | null } | null;
  testMode?: boolean;
}

// Helper function to format accommodation text with proper capitalization and syntax
const formatAccommodationText = (text: string): string => {
  return text
    // Fix common measurement formats (bed sizes, dimensions)
    .replace(/(\d+)\s*x\s*(\d+)/gi, '$1 × $2')
    // Capitalize after hyphens and at start
    .replace(/(?:^|\s-\s)([a-z])/g, (match, letter) => match.replace(letter, letter.toUpperCase()))
    // Capitalize first letter
    .replace(/^([a-z])/, (match, letter) => letter.toUpperCase())
    // Fix "shared bath with X" to "Shared bath with X"
    .replace(/shared\s+bath\s+with\s+([a-z])/gi, (match, letter) => `Shared bath with ${letter.toUpperCase()}`)
    // Fix "private bath" to "Private bath"
    .replace(/private\s+bath/gi, 'Private bath')
    // Fix room types
    .replace(/\bdouble\s+room\b/gi, 'Double room')
    .replace(/\bsingle\s+room\b/gi, 'Single room')
    .replace(/\btriple\s+room\b/gi, 'Triple room')
    // Fix bed references
    .replace(/\bbed\s+(\d+)/gi, 'Bed $1')
    // Clean up extra spaces
    .replace(/\s+/g, ' ')
    .trim();
};

// Helper function to get primary image (NEW IMAGES TABLE ONLY)
const getPrimaryImageUrl = (accommodation: ExtendedAccommodation): string | null => {
  // Don't show images for tent and van accommodations
  const title = accommodation.title.toLowerCase();
  if (title.includes('your own tent') || title.includes('van parking') || title.includes('your own van')) {
    return null;
  }
  
  // Check new images table for primary image
  const primaryImage = accommodation.images?.find(img => img.is_primary);
  if (primaryImage) return primaryImage.image_url;
  
  // If images exist but no primary, use first image
  if (accommodation.images && accommodation.images.length > 0) {
    return accommodation.images[0].image_url;
  }
  
  // Fallback to old image_url field if no images array
  return accommodation.image_url || null;
};

// Helper function to get all images sorted by display order
const getAllImages = (accommodation: ExtendedAccommodation): AccommodationImage[] => {
  // Don't show images for tent and van accommodations
  const title = accommodation.title.toLowerCase();
  if (title.includes('your own tent') || title.includes('van parking') || title.includes('your own van')) {
    return [];
  }
  
  if (!accommodation.images || accommodation.images.length === 0) {
    // Fallback: if no images array but has image_url, create a single image entry
    if (accommodation.image_url) {
      return [{
        id: `${accommodation.id}-primary`,
        accommodation_id: accommodation.id,
        image_url: accommodation.image_url,
        display_order: 0,
        is_primary: true,
        created_at: new Date().toISOString()
      }];
    }
    return [];
  }
  return [...accommodation.images].sort((a, b) => a.display_order - b.display_order);
};

// Helper Component for Overlays
const StatusOverlay: React.FC<{ 
  isVisible: boolean; 
  zIndex: number; 
  children: React.ReactNode; 
  className?: string; 
}> = ({ isVisible, zIndex, children, className }) => {
  if (!isVisible) return null;

  // Map numeric z-index to Tailwind classes
  const zIndexClass = {
    2: 'z-[2]',
    3: 'z-[3]',
    4: 'z-[4]',
    5: 'z-[5]'
  }[zIndex] || 'z-[1]';

  return (
    <div className={clsx("absolute inset-0 flex items-center justify-center p-4 pointer-events-none", zIndexClass)}> {/* Positioning only */}
      <div className={clsx(
        "bg-surface text-text-primary px-4 py-2 rounded-md font-mono text-sm text-center border border-border shadow-md pointer-events-auto",
        className // Allow specific styling overrides like border color
      )}>
        {children}
      </div>
    </div>
  );
};

export function CabinSelector({ 
  accommodations, 
  selectedAccommodationId, 
  onSelectAccommodation,
  isLoading = false,
  selectedWeeks = [],
  currentMonth = normalizeToUTCDate(new Date()),
  isDisabled = false,
  displayWeeklyAccommodationPrice,
  testMode = false
}: Props) {

  const { session } = useSession();
  const { isAdmin, isLoading: permissionsLoading } = useUserPermissions(session);
  const { pendingBookings } = usePendingBookings(selectedWeeks);
  

  // State for bathroom filters
  const [showOnlyWithBathrooms, setShowOnlyWithBathrooms] = useState(false);
  const [showOnlySharedBathrooms, setShowOnlySharedBathrooms] = useState(false);
  
  // State for price sorting
  const [sortBy, setSortBy] = useState<'default' | 'price-low' | 'price-high'>('default');
  
  // State for simple gallery
  const [galleryOpen, setGalleryOpen] = useState(false);
  const [galleryImages, setGalleryImages] = useState<{id: string, url: string, alt?: string}[]>([]);
  const [galleryTitle, setGalleryTitle] = useState<string>('');
  const [galleryStartIndex, setGalleryStartIndex] = useState(0);
  
  // State for accommodation info modal
  const [infoModalOpen, setInfoModalOpen] = useState(false);
  const [infoModalAccommodation, setInfoModalAccommodation] = useState<ExtendedAccommodation | null>(null);

  // Handler to open gallery
  const handleOpenGallery = useCallback((accommodation: ExtendedAccommodation, startIndex: number = 0) => {
    const images = getAllImages(accommodation);
    if (images.length > 0) {
      setGalleryImages(images.map(img => ({
        id: img.id,
        url: img.image_url,
        alt: accommodation.title
      })));
      setGalleryTitle(accommodation.title);
      setGalleryStartIndex(startIndex);
      setGalleryOpen(true);
    }
  }, []);

  // Simple Image Gallery Component using new components
  const ImageGallery: React.FC<{ accommodation: ExtendedAccommodation }> = ({ accommodation }) => {
    const allImages = getAllImages(accommodation);

    if (allImages.length === 0) {
      return (
        <div className="w-full h-full flex items-center justify-center text-secondary bg-gray-100">
          <BedDouble size={32} />
        </div>
      );
    }

    return (
      <SimpleThumbnailGallery
        images={allImages.map(img => ({
          id: img.id,
          url: img.image_url,
          alt: accommodation.title
        }))}
        onImageClick={(index) => handleOpenGallery(accommodation, index)}
        className="w-full h-full"
      />
    );
  };



  // --- Normalization Step ---
  // currentMonth is already normalized in the prop default
  const normalizedCurrentMonth = currentMonth;
  // --- End Normalization ---

  const { checkWeekAvailability, availabilityMap } = useWeeklyAccommodations();
  


  // PERFORMANCE FIX: Memoize price info for each accommodation to prevent re-calculation on every render
  const memoizedPriceInfo = useMemo(() => {
    const priceMap: Record<string, { price: number | null; avgSeasonalDiscount: number | null }> = {};
    
    if (accommodations && accommodations.length > 0) {
      accommodations.forEach(acc => {
        if ((acc as any).parent_accommodation_id) return;
        const info = displayWeeklyAccommodationPrice(acc.id);
        priceMap[acc.id] = info ?? { price: null, avgSeasonalDiscount: null };
      });
    }
    
    return priceMap;
  }, [accommodations, displayWeeklyAccommodationPrice]);

  // OPTIMIZED: Use memoized price info instead of calling getDisplayInfo during render
  const getDisplayInfoOptimized = useCallback((accommodationId: string): { price: number | null; avgSeasonalDiscount: number | null } | null => {
    const info = memoizedPriceInfo[accommodationId];
    return info ?? null;
  }, [memoizedPriceInfo]);

  // Helper function for consistent price formatting
  const formatPrice = (price: number | null, isTest: boolean): string => {
    if (price === null) return 'N/A';
    if (price === 0) return 'Free';
    if (price === 0.5) return '0.5'; // Preserve specific edge case
    if (isTest) return price.toString(); // Show exact value for test accommodations

    // For regular accommodations, format with thousand separators
    if (Number.isInteger(price)) {
      // Format integer prices with comma as thousand separator
      return price.toLocaleString('en-US');
    } else {
      // For decimal prices, format with thousand separators and 2 decimal places
      return price.toLocaleString('en-US', { minimumFractionDigits: 2, maximumFractionDigits: 2 });
    }
  };

  // Clear selection if selected accommodation becomes unavailable (unless in test mode)
  useEffect(() => {
    if (selectedAccommodationId && selectedWeeks.length > 0) {
      if (testMode) {
        return;
      }
      
      const isAvailable = availabilityMap[selectedAccommodationId]?.isAvailable;
      
      if (!isAvailable) {
        onSelectAccommodation('');
      }
    }
  }, [selectedAccommodationId, selectedWeeks, availabilityMap, onSelectAccommodation, testMode]);

  // NEW: Clear accommodation selection when dates are cleared
  useEffect(() => {
    if (selectedWeeks.length === 0 && selectedAccommodationId) {
      onSelectAccommodation('');
    }
  }, [selectedWeeks, selectedAccommodationId, onSelectAccommodation]);

  useEffect(() => {
    if (selectedWeeks.length > 0) {
      // Check availability for all accommodations when weeks are selected
      
      // MODIFIED: Determine overall check-in and check-out dates
      const checkInDate = selectedWeeks.length > 0 ? selectedWeeks[0].startDate : null;
      const checkOutDate = selectedWeeks.length > 0 ? selectedWeeks[selectedWeeks.length - 1].endDate : null;

      accommodations.forEach(acc => {
        if (!(acc as any).parent_accommodation_id) { // Only check parent accommodations
          // MODIFIED: Pass derived dates to checkWeekAvailability
          checkWeekAvailability(acc, checkInDate, checkOutDate);
        }
      });
    }
    // MODIFIED: Dependency array includes derived dates implicitly via selectedWeeks
  }, [selectedWeeks, accommodations, checkWeekAvailability]);

  const handleSelectAccommodation = useCallback((id: string, accommodation?: ExtendedAccommodation) => {
    // NEW: If clicking the already selected accommodation, deselect it
    if (id === selectedAccommodationId) {
      onSelectAccommodation('');
      return; // Stop further execution
    }

    // REMOVED: No longer checking availability here since useEffect[selectedWeeks] already does it
    // This was causing double API calls and state thrashing leading to flickering

    onSelectAccommodation(id);
    
    // Show info modal when accommodation is selected
    if (accommodation) {
      setInfoModalAccommodation(accommodation);
      setInfoModalOpen(true);
    }
  }, [onSelectAccommodation, selectedAccommodationId]);

  // Helper function to check if user can see test accommodations
  const canSeeTestAccommodations = () => {
    if (isAdmin) return true;
    
    const userEmail = session?.user?.email;
    if (!userEmail) return false;
    
    // Check if email matches redis213+...@gmail.com pattern
    const testEmailPattern = /^redis213\+.*@gmail\.com$/i;
    const canSeeTests = testEmailPattern.test(userEmail);
    
    return canSeeTests;
  };

  // Helper function to determine bathroom type from description or bathroom_type field
  const getBathroomType = (accommodation: ExtendedAccommodation): 'private' | 'shared' => {
    // First check the bathroom_type field if it exists and is valid
    if (accommodation.bathroom_type === 'private') {
      return 'private';
    }
    if (accommodation.bathroom_type === 'shared') {
      return 'shared';
    }
    
    // Check description for specific bathroom indicators
    const desc = accommodation.description || '';
    const additionalInfo = accommodation.additional_info || '';
    const fullText = (desc + ' ' + additionalInfo).toLowerCase();
    
    // Check for shared bathroom indicators first (more specific)
    if (/\bshared\s+(bath|bathroom)/i.test(fullText) || 
        /\bshared\s+facilities/i.test(fullText) || 
        /\bcommunal\s+(bath|bathroom)/i.test(fullText)) {
      return 'shared';
    }
    
    // Check for private bathroom indicators
    if (/\bprivate\s+(bath|bathroom)/i.test(fullText) || 
        /\bensuite\b/i.test(fullText) || 
        /\ben-suite\b/i.test(fullText) || 
        /\bown\s+(bath|bathroom)/i.test(fullText)) {
      return 'private';
    }
    
    // Check if mentions 'bath' or 'bathroom' WITHOUT being preceded by 'shared'
    if (/\bbath(room)?\b/i.test(fullText) && !/\bshared\s+(bath|bathroom)/i.test(fullText)) {
      return 'private';
    }
    
    // Default based on accommodation type patterns
    const title = accommodation.title.toLowerCase();
    if (title.includes('micro cabin') || title.includes('attic') || title.includes('dovecote')) {
      return 'private';
    }
    if (title.includes('dorm') || title.includes('bell tent') || title.includes('tipi') || title.includes('own tent') || title.includes('van')) {
      return 'shared';
    }
    
    // Default fallback - ensure we ALWAYS return either 'private' or 'shared'
    return 'shared';
  };

  // Debug accommodations loading
  console.log(`[CabinSelector] Total accommodations loaded: ${accommodations.length}`);
  console.log(`[CabinSelector] Accommodations:`, accommodations);
  console.log(`[CabinSelector] Filter states - Private: ${showOnlyWithBathrooms}, Shared: ${showOnlySharedBathrooms}`);
  
  // Filter accommodations based on season and type
  const visibleAccommodations = accommodations
    .filter(acc => {
      console.log(`[CabinSelector] Processing: ${acc.title} (${acc.id})`);
      
      // Filter out individual bed entries
      if ((acc as any).parent_accommodation_id) {
        console.log(`[CabinSelector] - Filtered out: Has parent accommodation`);
        return false;
      }

      // Filter out 'test' accommodations if the user is NOT an admin AND NOT a test user
      if (acc.type === 'test' && !canSeeTestAccommodations()) {
        console.log(`[CabinSelector] - Filtered out: Test accommodation`);
        return false;
      }

      const bathroomType = getBathroomType(acc);
      console.log(`[CabinSelector] - Bathroom type: ${bathroomType}`);
      
      // Filter by bathroom if enabled
      if (showOnlyWithBathrooms && bathroomType !== 'private') {
        console.log(`[CabinSelector] - Filtered out: Private filter enabled but this is ${bathroomType}`);
        return false;
      }

      // Filter by shared bathroom if enabled
      if (showOnlySharedBathrooms && bathroomType !== 'shared') {
        console.log(`[CabinSelector] - Filtered out: Shared filter enabled but this is ${bathroomType}`);
        return false;
      }

      console.log(`[CabinSelector] - ✅ Passed all filters`);
      return true;
    })
    .sort((a, b) => {
      // Price sorting takes priority if selected
      if (sortBy !== 'default') {
        // Get the actual weekly price for each accommodation
        const aPrice = memoizedPriceInfo[a.id]?.price ?? a.base_price;
        const bPrice = memoizedPriceInfo[b.id]?.price ?? b.base_price;
        
        if (sortBy === 'price-low') {
          // Sort by price low to high
          if (aPrice !== bPrice) {
            return aPrice - bPrice;
          }
        } else if (sortBy === 'price-high') {
          // Sort by price high to low
          if (aPrice !== bPrice) {
            return bPrice - aPrice;
          }
        }
      }
      
      // Default sorting logic
      const getPriority = (acc: typeof a) => {
        const title = acc.title.toLowerCase();
        
        // Priority 1: Own tent/van (first on site)
        if (title.includes('own tent') || title.includes('your own tent')) return 1;
        if (title.includes('own van') || title.includes('van parking') || title.includes('your own van')) return 2;
        
        // Priority 2: Le Dorm (new budget option)
        if (title === 'le dorm') return 3;
        
        // Priority 3: Fixed price glamping (tipi and bell tent)
        if (title.includes('single tipi')) return 4;
        if (title.includes('bell tent')) return 5;
        
        // Priority 4: Other glamping options
        if (title.includes('microcabin')) return 10;
        if (title.includes('yurt')) return 11;
        if (title.includes('a-frame')) return 12;
        
        // Priority 5: Other dorms
        if (title.includes('dorm') && title !== 'le dorm') return 15;
        
        // Priority 6: Castle rooms by location
        const location = acc.property_location;
        if (location === 'dovecote') return 20;
        if (location === 'renaissance') return 21;
        if (location === 'medieval') return 22;
        if (location === 'oriental') return 23;
        if (location === 'palm_grove') return 24;
        
        // Everything else
        return 99;
      };
      
      const aPriority = getPriority(a);
      const bPriority = getPriority(b);
      
      // Sort by priority
      if (aPriority !== bPriority) {
        return aPriority - bPriority;
      }
      
      // Within same priority (e.g., same location), sort Renaissance rooms by floor
      if (a.property_location === 'renaissance' && b.property_location === 'renaissance') {
        const sectionOrder = { 'mezzanine': 1, 'first_floor': 2, 'second_floor': 3, 'attic': 4 };
        const aSection = sectionOrder[a.property_section as keyof typeof sectionOrder] || 5;
        const bSection = sectionOrder[b.property_section as keyof typeof sectionOrder] || 5;
        if (aSection !== bSection) return aSection - bSection;
      }
      
      // Within same priority/section, sort by price (higher first for castle rooms, lower first for budget options)
      if (aPriority >= 20) {
        // Castle rooms - higher price first
        return b.base_price - a.base_price;
      } else {
        // Budget options - lower price first
        return a.base_price - b.base_price;
      }
    });

  console.log(`[CabinSelector] Final visible accommodations count: ${visibleAccommodations.length}`);
  console.log(`[CabinSelector] Visible accommodations:`, visibleAccommodations.map(acc => `${acc.title} (${acc.id})`));

  // Convert selectedWeeks to dates for comparison
  const selectedDates = selectedWeeks?.map(w => w.startDate || w) || [];
  
  // Check if it's tent season (April 15 - September 1)
  // For tent season calculation, we'll use the first selected week's start date
  // If no weeks are selected, we'll use the current month for display purposes
  const firstSelectedDate = selectedWeeks.length > 0 
    ? (selectedWeeks[0].startDate || normalizeToUTCDate(new Date())) 
    : normalizeToUTCDate(new Date());
  
  const isTentSeason = (() => {
    if (selectedWeeks.length === 0) {
      const m = normalizedCurrentMonth.getUTCMonth();
      const d = normalizedCurrentMonth.getUTCDate();
      return (m > 3 || (m === 3 && d >= 15)) && 
             (m < 9 || (m === 9 && d <= 7)); // Ends Oct 7th inclusive
    }
    
    const isInTentSeason = (date: Date) => {
      const m = date.getUTCMonth();
      const d = date.getUTCDate();
      // April 15th to October 7th inclusive
      return (m > 3 || (m === 3 && d >= 15)) && (m < 9 || (m === 9 && d <= 7));
    };
    
    let allDays: Date[] = [];
    selectedWeeks.forEach(week => {
      const startDate = normalizeToUTCDate(week.startDate || (week instanceof Date ? week : new Date()));
      const endDate = normalizeToUTCDate(week.endDate || addDays(startDate, 6));
      if (isBefore(endDate, startDate)) return;
      let currentDay = new Date(startDate);
      while (currentDay < endDate) { // Use < to match pricing util logic (nights)
        allDays.push(new Date(currentDay));
        currentDay = addDays(currentDay, 1); // Use addDays instead of setUTCDate
      }
    });
    // For tent availability, ALL days of the stay must be within tent season
    // A tent can only be booked if the entire stay is within April 15 - Oct 7
    return allDays.length > 0 && allDays.every(isInTentSeason);
  })();

  return (
    <div className="space-y-6" style={{ position: 'relative' }}>
      {/* Pricing Explainer */}
      <div className="mb-6 p-4 bg-surface/50 border border-border/50 rounded-sm">
        <p className="text-sm text-secondary leading-relaxed">
          How this works: rooms subsidize the event. We pick people for values and energy, not money, 
          so there's a financial asymmetry that makes the whole thing possible at this price.
        </p>
      </div>

      {/* Filter and Sort options */}
      <div className="flex flex-col gap-4 mb-4">
        {/* Bathroom Filters */}
        <div className="flex items-center gap-4 flex-wrap">
          <button
            onClick={() => {
              setShowOnlyWithBathrooms(!showOnlyWithBathrooms);
              if (showOnlySharedBathrooms) setShowOnlySharedBathrooms(false);
            }}
            className={clsx(
              "flex items-center gap-2 px-4 py-2 rounded-sm border transition-all duration-200 font-mono text-sm",
              showOnlyWithBathrooms 
                ? "bg-accent-primary text-white border-accent-primary" 
                : "bg-surface text-secondary border-border hover:border-accent-primary"
            )}
          >
            <Bath size={16} />
            <span>Private Bathrooms</span>
            {showOnlyWithBathrooms && (
              <span className="ml-1 text-xs opacity-90">
                ({accommodations.filter(acc => {
                  if ((acc as any).parent_accommodation_id) return false;
                  const bathroomType = getBathroomType(acc);
                  return bathroomType === 'private';
                }).length})
              </span>
            )}
          </button>
          
          <button
            onClick={() => {
              setShowOnlySharedBathrooms(!showOnlySharedBathrooms);
              if (showOnlyWithBathrooms) setShowOnlyWithBathrooms(false);
            }}
            className={clsx(
              "flex items-center gap-2 px-4 py-2 rounded-sm border transition-all duration-200 font-mono text-sm",
              showOnlySharedBathrooms 
                ? "bg-accent-primary text-white border-accent-primary" 
                : "bg-surface text-secondary border-border hover:border-accent-primary"
            )}
          >
            <Users size={16} />
            <span>Shared Bathrooms</span>
            {showOnlySharedBathrooms && (
              <span className="ml-1 text-xs opacity-90">
                ({accommodations.filter(acc => {
                  if ((acc as any).parent_accommodation_id) return false;
                  const bathroomType = getBathroomType(acc);
                  return bathroomType === 'shared';
                }).length})
              </span>
            )}
          </button>
        </div>
        
        {/* Price Sorting */}
        <div className="flex items-center gap-2">
          <span className="text-sm text-secondary font-mono">Sort by:</span>
          <div className="flex items-center gap-2">
            <button
              onClick={() => setSortBy('default')}
              className={clsx(
                "flex items-center gap-2 px-4 py-2 rounded-sm border transition-all duration-200 font-mono text-sm",
                sortBy === 'default'
                  ? "bg-accent-primary text-white border-accent-primary"
                  : "bg-surface text-secondary border-border hover:border-accent-primary"
              )}
            >
              <ArrowUpDown size={16} />
              <span>Default</span>
            </button>
            
            <button
              onClick={() => setSortBy('price-low')}
              className={clsx(
                "flex items-center gap-2 px-4 py-2 rounded-sm border transition-all duration-200 font-mono text-sm",
                sortBy === 'price-low'
                  ? "bg-accent-primary text-white border-accent-primary"
                  : "bg-surface text-secondary border-border hover:border-accent-primary"
              )}
            >
              <ArrowUp size={16} />
              <span>Price: Low to High</span>
            </button>
            
            <button
              onClick={() => setSortBy('price-high')}
              className={clsx(
                "flex items-center gap-2 px-4 py-2 rounded-sm border transition-all duration-200 font-mono text-sm",
                sortBy === 'price-high'
                  ? "bg-accent-primary text-white border-accent-primary"
                  : "bg-surface text-secondary border-border hover:border-accent-primary"
              )}
            >
              <ArrowDown size={16} />
              <span>Price: High to Low</span>
            </button>
          </div>
        </div>
      </div>
      
      {isLoading ? (
        <div className="max-w-2xl">
          <div className="grid grid-cols-1 sm:grid-cols-2 gap-4">
            {[...Array(4)].map((_, i) => (
              <div key={i} className="rounded-sm border border-border bg-surface p-4 h-[300px] animate-pulse">
                <div className="h-32 bg-border/50 rounded mb-3"></div>
                <div className="h-4 bg-border/50 rounded w-3/4 mb-2"></div>
                <div className="h-3 bg-border/50 rounded w-1/2 mb-4"></div>
                <div className="h-8 bg-border/50 rounded w-1/4"></div>
              </div>
            ))}
          </div>
        </div>
      ) : visibleAccommodations.length === 0 ? (
        <div className="text-center py-12 bg-surface rounded-sm border border-border">
          <h3 className="text-lg font-medium text-primary mb-2 font-mono">
            {showOnlyWithBathrooms 
              ? 'No rooms with private bathrooms available' 
              : showOnlySharedBathrooms 
                ? 'No rooms with shared bathrooms available'
                : 'No accommodations available'}
          </h3>
          <p className="text-secondary font-mono">
            {(showOnlyWithBathrooms || showOnlySharedBathrooms)
              ? 'Try removing the bathroom filter or adjusting your dates.' 
              : 'Please adjust your dates or check back later.'}
          </p>
        </div>
      ) : (
        <div>
          <div className="grid grid-cols-1 sm:grid-cols-2 2xl:grid-cols-3 gap-4">
            {/* Special combined card for tent and van */}
            {(() => {
              const tentAcc = visibleAccommodations.find(acc => 
                acc.title.toLowerCase().includes('own tent') || 
                acc.title.toLowerCase().includes('your own tent')
              );
              const vanAcc = visibleAccommodations.find(acc => 
                acc.title.toLowerCase().includes('own van') || 
                acc.title.toLowerCase().includes('your own van') || 
                acc.title.toLowerCase().includes('van parking')
              );
              
              if (tentAcc || vanAcc) {
                return (
                  <motion.div
                    key="tent-van-combined"
                    layout
                    initial={{ opacity: 0, scale: 0.95 }}
                    animate={{ opacity: 1, scale: 1 }}
                    transition={{ duration: 0.2 }}
                    className="relative rounded-sm overflow-hidden bg-surface flex flex-col border border-border"
                    style={{ minHeight: '300px' }}
                  >
                    <div className="flex flex-col h-full">
                      {/* Tent Button */}
                      {tentAcc && (
                        <button
                          onClick={() => {
                            if (tentAcc.sold_out) return;
                            if (testMode || (selectedWeeks.length > 0 && !isDisabled)) {
                              handleSelectAccommodation(tentAcc.id, tentAcc);
                            }
                          }}
                          className={clsx(
                            "flex-1 p-4 border-b border-border transition-all duration-200 flex flex-col justify-center items-center min-h-[150px]",
                            // Add hover effect only when not sold out
                            !tentAcc.sold_out && "hover:bg-surface-hover",
                            selectedAccommodationId === tentAcc.id && "bg-[color-mix(in_srgb,_var(--color-bg-surface)_95%,_var(--color-accent-primary)_5%)] shadow-lg",
                            // Enhanced sold out styling
                            tentAcc.sold_out && "opacity-100 cursor-not-allowed pointer-events-none",
                            // Regular disabled state
                            !tentAcc.sold_out && (!testMode && (!selectedWeeks.length || isDisabled)) && "opacity-50 cursor-not-allowed"
                          )}
                        >
                          <h3 className="text-lg font-medium text-primary font-lettra-bold uppercase mb-2">YOUR OWN TENT</h3>
                          {tentAcc.sold_out ? (
                            <span className="text-red-600 text-xl font-bold font-mono tracking-wider">SOLD OUT</span>
                          ) : (
                            <span className="text-accent-primary text-xl font-lettra-bold font-mono">Free</span>
                          )}
                        </button>
                      )}
                      
                      {/* Van Button */}
                      {vanAcc && (
                        <button
                          onClick={() => {
                            if (vanAcc.sold_out) return;
                            if (testMode || (selectedWeeks.length > 0 && !isDisabled)) {
                              handleSelectAccommodation(vanAcc.id, vanAcc);
                            }
                          }}
                          className={clsx(
                            "flex-1 p-4 transition-all duration-200 flex flex-col justify-center items-center min-h-[150px]",
                            // Add hover effect only when not sold out
                            !vanAcc.sold_out && "hover:bg-surface-hover",
                            selectedAccommodationId === vanAcc.id && "bg-[color-mix(in_srgb,_var(--color-bg-surface)_95%,_var(--color-accent-primary)_5%)] shadow-lg",
                            // Enhanced sold out styling
                            vanAcc.sold_out && "opacity-100 cursor-not-allowed pointer-events-none",
                            // Regular disabled state
                            !vanAcc.sold_out && (!testMode && (!selectedWeeks.length || isDisabled)) && "opacity-50 cursor-not-allowed"
                          )}
                        >
                          <h3 className="text-lg font-medium text-primary font-lettra-bold uppercase mb-2">YOUR OWN VAN</h3>
                          {vanAcc.sold_out ? (
                            <span className="text-red-600 text-xl font-bold font-mono tracking-wider">SOLD OUT</span>
                          ) : (
                            <span className="text-accent-primary text-xl font-lettra-bold font-mono">Free</span>
                          )}
                        </button>
                      )}
                    </div>
                  </motion.div>
                );
              }
              return null;
            })()}
            
            {/* Regular accommodation cards (excluding tent and van) */}
            {visibleAccommodations.filter(acc => 
              !acc.title.toLowerCase().includes('own tent') && 
              !acc.title.toLowerCase().includes('your own tent') &&
              !acc.title.toLowerCase().includes('own van') && 
              !acc.title.toLowerCase().includes('your own van') && 
              !acc.title.toLowerCase().includes('van parking')
            ).map((acc) => {
              
              const isSelected = selectedAccommodationId === acc.id;
              const availability = availabilityMap[acc.id];
              const isAvailable = availability?.isAvailable ?? true;
              const isFullyBooked = !isAvailable;
              const spotsAvailable = availability?.availableCapacity;
              const canSelect = testMode || (!isDisabled && !isFullyBooked);

              const isTent = acc.type === 'tent';
              const isOutOfSeason = isTent && !isTentSeason && selectedWeeks.length > 0;
              const finalCanSelect = testMode || (canSelect && !isOutOfSeason);

              // Get all images for the current accommodation to use for the counter
              const allImagesForAcc = getAllImages(acc);

              const isInAuction = false;
              const auctionPricing = null;
              
              // Get the pricing info
              const weeklyInfo = getDisplayInfoOptimized(acc.id);
              
              let weeklyPrice = weeklyInfo?.price ?? null;
              const avgSeasonalDiscountForTooltip = weeklyInfo?.avgSeasonalDiscount ?? null;

              // Keep duration discount calculation local to tooltip
              const completeWeeksForDiscount = calculateDurationDiscountWeeks(selectedWeeks);
              const currentDurationDiscount = getDurationDiscount(completeWeeksForDiscount);
              
              // --- START TEST ACCOMMODATION OVERRIDE ---
              let isTestAccommodation = acc.type === 'test';
              if (isTestAccommodation) {
                weeklyPrice = 0.5; // Override price
              }
              // --- END TEST ACCOMMODATION OVERRIDE ---

              // Use the avgSeasonalDiscount from the prop for the flag, exclude test accommodations
              // Original check: (avgSeasonalDiscountForTooltip !== null && avgSeasonalDiscountForTooltip > 0 && !acc.title.toLowerCase().includes('dorm')) || currentDurationDiscount > 0;
              const hasSeasonalDiscount = avgSeasonalDiscountForTooltip !== null && avgSeasonalDiscountForTooltip > 0 && !acc.title.toLowerCase().includes('dorm');
              const hasDurationDiscount = currentDurationDiscount > 0;
              const hasAnyDiscount = !isTestAccommodation && (hasSeasonalDiscount || hasDurationDiscount); // <-- Modified: Exclude test type
              
              // No longer need special tent/van styling since they have their own card
              const isTentOrVan = false;
              
              return (
                <motion.div
                  key={acc.id}
                  layout
                  initial={{ opacity: 0, scale: 0.95 }}
                  animate={{ opacity: 1, scale: 1 }}
                  transition={{ duration: 0.2 }}
                  className={clsx(
                    // Base classes - adjust for tent/van stacking
                    'relative rounded-sm overflow-hidden transition-all duration-200 flex flex-col justify-between group',
                    isTentOrVan ? 'mb-2' : 'mb-4', // Smaller margin for tent/van to stack closer
                    // Apply bg-surface by default, override when selected, add shadow only when selected
                    isSelected 
                      ? "shadow-lg bg-[color-mix(in_srgb,_var(--color-bg-surface)_95%,_var(--color-accent-primary)_5%)]" 
                      : "bg-surface", // Use the renamed class
                    // Sold out state - enhanced styling
                    acc.sold_out && "opacity-100",
                    // Pointer state:
                    (testMode || (finalCanSelect && !isDisabled)) && !acc.sold_out && 'cursor-pointer',
                    // Disable hover effects for sold out items
                    acc.sold_out && 'pointer-events-none'
                  )}
                  onClick={(e) => {
                    // Check if click is on interactive elements that should not trigger selection
                    const target = e.target as HTMLElement;
                    
                    // Don't select if clicking on buttons, links, or other interactive elements
                    if (target.closest('button') || target.closest('a')) {
                      return;
                    }
                    
                    // Don't allow selection if sold out
                    if (acc.sold_out) {
                      return;
                    }
                    
                    // Only select accommodation if clicking is allowed
                    if (testMode || (finalCanSelect && !isDisabled)) {
                      handleSelectAccommodation(acc.id, acc);
                    }
                  }}
                  style={{ 
                    minHeight: '300px' // Keep standard height for all cards
                  }} 
                >
                  {/* Use the StatusOverlay helper component */}
                  <StatusOverlay isVisible={acc.sold_out} zIndex={5}>
                    <span className="text-red-600 font-bold text-lg tracking-wider">SOLD OUT</span>
                  </StatusOverlay>
                  <StatusOverlay isVisible={!testMode && isDisabled && !acc.sold_out} zIndex={4}>
                    Select dates first
                  </StatusOverlay>
                  <StatusOverlay isVisible={!testMode && !isDisabled && isFullyBooked && !acc.sold_out} zIndex={3}>
                    {pendingBookings[acc.id] && pendingBookings[acc.id].count > 0 ? 'Being booked' : 'Booked out'}
                  </StatusOverlay>
                  <StatusOverlay 
                    isVisible={!testMode && !isDisabled && isOutOfSeason && !isFullyBooked && !acc.sold_out} 
                    zIndex={2}
                    className="border-amber-500 dark:border-amber-600" // Pass specific class for amber border
                  >
                    Seasonal<br />Apr 15 - Oct 7
                  </StatusOverlay>

                  {/* Badge container - place above overlays */}
                  <div className="absolute top-2 left-2 z-[5] flex flex-col gap-2"> 
                    {/* Pending Booking Indicator */}
                    {pendingBookings[acc.id] && pendingBookings[acc.id].count > 0 && (
                      <div className="text-xs font-medium px-3 py-1 rounded-full shadow-lg bg-amber-600/90 text-white border border-amber-300/30 font-mono flex items-center gap-1">
                        <Clock size={12} className="animate-pulse" />
                        <span>
                          Being booked now
                          {pendingBookings[acc.id].minutesRemaining > 0 && (
                            <span className="opacity-90">
                              {' '}(available in {pendingBookings[acc.id].minutesRemaining}m)
                            </span>
                          )}
                        </span>
                      </div>
                    )}
                    {/* Spots Available Indicator */}
                    {spotsAvailable !== undefined && spotsAvailable !== null && spotsAvailable < (acc.inventory ?? Infinity) && !isFullyBooked && !isOutOfSeason && !isDisabled && acc.type !== 'tent' && (
                      <div className="text-xs font-medium px-3 py-1 rounded-full shadow-lg bg-gray-600/90 text-white border border-white/30 font-mono">{spotsAvailable} {spotsAvailable === 1 ? 'spot' : 'spots'} available</div>
                    )}
                  </div>

                  {/* Top-right badges container */}
                  <div className="absolute top-2 right-2 z-10 flex flex-col items-end gap-2">
                    {/* Capacity Badge */}
                    {acc.capacity && selectedWeeks.length > 0 && !isFullyBooked && (!['parking', 'tent'].includes(acc.type) || acc.title.toLowerCase().includes('tipi') || acc.title.toLowerCase().includes('bell tent')) && !acc.title.toLowerCase().includes('van parking') && !acc.title.toLowerCase().includes('own tent') && !acc.title.toLowerCase().includes('staying with somebody') && !acc.title.toLowerCase().includes('dorm') && (
                      <div className="text-xs font-medium px-3 py-1 rounded-full shadow-lg bg-gray-600/90 text-white border border-white/30 font-mono">
                        Fits {acc.capacity} {acc.capacity === 1 ? 'person' : 'people'}
                      </div>
                    )}
                  </div>

                  {/* Image - hide for "your own tent" and "van parking" */}
                  {!isTentOrVan && (
                    <div className={clsx(
                      "relative h-56 overflow-hidden", // REMOVED bg-surface
                      // Apply blur and corresponding opacity/grayscale conditionally
                      !testMode && isDisabled && "opacity-50 grayscale-[0.5]",
                      !testMode && (!isDisabled && isFullyBooked) && "opacity-50 grayscale-[0.7]",
                      !testMode && (!isDisabled && isOutOfSeason && !isFullyBooked) && "opacity-60 grayscale-[0.3]"
                    )}>
                      <ImageGallery accommodation={acc} />
                      <div className="absolute inset-0 bg-gradient-to-t from-black/60 to-transparent pointer-events-none"></div> {/* Increased gradient opacity from 40% to 60% */}
                    </div>
                  )}

                  {/* Content */}
                  <div className={clsx(
                    "p-3 flex-grow flex flex-col justify-between", // Base classes
                    // REMOVED background logic here - relies on parent motion.div now
                    // Apply blur and corresponding opacity/grayscale conditionally
                    !testMode && isDisabled && "blur-sm opacity-20 grayscale-[0.5]",
                    !testMode && (!isDisabled && isFullyBooked) && "blur-sm opacity-20 grayscale-[0.7]",
                    !testMode && (!isDisabled && isOutOfSeason && !isFullyBooked) && "blur-sm opacity-40 grayscale-[0.3]"
                  )}>
                    <div>
                      {!isTentOrVan && (
                        <h3 className="text-lg font-medium mb-1 text-primary font-lettra-bold uppercase">{acc.title}</h3>
                      )}
                      {/* Property Location Badge */}
                      <div className="mb-2 flex items-center gap-2 flex-wrap">
                        {acc.property_location && (
                          <span className="inline-flex items-center px-2 py-1 rounded-sm text-xs font-medium bg-amber-900/20 text-amber-200 border border-amber-700/30">
                            {acc.property_location === 'dovecote' && '🕊️ Dovecote'}
                            {acc.property_location === 'renaissance' && (
                              <>
                                🏛️ Renaissance
                                {acc.property_section && (
                                  <span className="ml-1 opacity-90">
                                    · {acc.property_section === 'mezzanine' && 'Mezzanine'}
                                    {acc.property_section === 'first_floor' && '1st Floor'}
                                    {acc.property_section === 'second_floor' && '2nd Floor'}
                                    {acc.property_section === 'attic' && 'Attic'}
                                  </span>
                                )}
                              </>
                            )}
                            {acc.property_location === 'oriental' && '🏮 Oriental'}
                            {acc.property_location === 'palm_grove' && '🌴 Palm Grove'}
                            {acc.property_location === 'medieval' && '🏰 Medieval'}
                          </span>
                        )}
                        {/* Bathroom Type Badge */}
                        {acc.bathroom_type && acc.bathroom_type !== 'none' && (
                          <span className={clsx(
                            "inline-flex items-center gap-1 px-2 py-1 rounded-sm text-xs font-medium",
                            acc.bathroom_type === 'private' 
                              ? "bg-blue-500/20 text-blue-300 border border-blue-500/30" 
                              : "bg-gray-600/20 text-gray-300 border border-gray-600/30"
                          )}>
                            {acc.bathroom_type === 'private' ? (
                              <>
                                <Bath size={10} />
                                <span>Private</span>
                              </>
                            ) : (
                              <>
                                <Users size={10} />
                                <span>Shared</span>
                              </>
                            )}
                          </span>
                        )}
                      </div>
                      {/* Additional Info - Display as formatted text with icons */}
                      {acc.additional_info && (
                        <div className="text-secondary text-xs mb-3 space-y-1">
                          {acc.additional_info.split('•').map((info, idx) => {
                            const rawInfo = info.trim();
                            if (!rawInfo) return null;
                            
                            // Format the text with proper capitalization and syntax
                            const trimmedInfo = formatAccommodationText(rawInfo);
                            
                            // Add icons for specific amenities
                            let icon = null;
                            let highlightClass = "";
                            
                            if (trimmedInfo.toLowerCase().includes('bed')) {
                              icon = <BedDouble size={12} className="inline mr-1" />;
                            } else if (trimmedInfo.toLowerCase().includes('private') && trimmedInfo.toLowerCase().includes('bath')) {
                              icon = <Bath size={12} className="inline mr-1 text-accent-primary" />;
                              highlightClass = "text-accent-primary font-medium";
                            } else if (trimmedInfo.toLowerCase().includes('shared') && trimmedInfo.toLowerCase().includes('bath')) {
                              icon = <Users size={12} className="inline mr-1" />;
                            } else if (trimmedInfo.toLowerCase().includes('bath') || trimmedInfo.toLowerCase().includes('shower') || trimmedInfo.toLowerCase().includes('tub')) {
                              icon = <Bath size={12} className="inline mr-1" />;
                            }
                            
                            return (
                              <div key={idx} className="flex items-start">
                                <span className="mr-1">•</span>
                                <span className={highlightClass}>
                                  {icon}
                                  {trimmedInfo}
                                </span>
                              </div>
                            );
                          })}
                        </div>
                      )}
                      
                      {/* Quiet Zone for Microcabins */}
                      {acc.title.includes('Microcabin') && (
                        <div className="flex items-center gap-1 text-secondary text-xs mb-3">
                          <Ear size={12} />
                          <span>We invite those who seek quiet to stay here.</span>
                        </div>
                      )}
                    </div>
                    
                    <div className="flex justify-between items-end">
                      <div className="text-primary font-medium font-mono">
                        {/* Pricing Type Label */}
                        {acc.title === 'Single Tipi' || acc.title === '4 Meter Bell Tent' || acc.title === '4m Bell Tent' || acc.title === 'Le Dorm' ? (
                          <span className="text-xs text-gray-400 uppercase tracking-wide">Fixed Price</span>
                        ) : null}
                        
                        {/* Check if weeklyPrice (from prop) is null or 0, handle 0.01 specifically */}
                        {weeklyPrice === null || weeklyPrice === 0 ? (
                          <span className="text-accent-primary text-xl font-lettra-bold font-mono">{formatPrice(weeklyPrice, isTestAccommodation)}</span>
                        ) : (
                          <div className="flex flex-col">
                            <span className="text-xl font-lettra-bold text-accent-primary">
                              €{formatPrice(weeklyPrice, isTestAccommodation)}
                              <span className="text-xl text-secondary font-lettra-bold"></span>
                            </span>
                            {isInAuction && auctionPricing && (
                              <span className="text-xs text-secondary font-mono mt-1">
                                Floor: €{formatPrice(auctionPricing.floorPrice, false)}
                              </span>
                            )}
                          </div>
                        )}
                      </div>
                      
                      {/* Ensure weeklyPrice is not null for discount display, and check hasAnyDiscount flag */}
                      {weeklyPrice !== null && weeklyPrice > 0 && hasAnyDiscount && (
                        <HoverClickPopover
                          triggerContent={<Percent size={14} />}
                          triggerWrapperClassName="text-accent-primary flex items-center gap-0.5 cursor-default" // Custom trigger style
                          contentClassName="tooltip-content tooltip-content--accent !font-mono z-50" // Custom content style
                          arrowClassName="tooltip-arrow tooltip-arrow--accent" // Custom arrow style
                          popoverContentNode={(
                            <>
                              <h4 className="font-medium font-mono mb-2">Weekly Rate Breakdown</h4>
                              <div className="text-sm space-y-2">
                                 {/* Base Price */}
                                 <div className="flex justify-between items-center color-shade-2">
                                    <span>Base Rate:</span>
                                    <span>€{Math.round(acc.base_price)} / week</span>
                                 </div>
                                
                                {/* Seasonal Discount - Use avgSeasonalDiscount from prop, ensure not null */}
                                {hasSeasonalDiscount && avgSeasonalDiscountForTooltip !== null && ( // Added null check here
                                  <div className="flex justify-between items-center">
                                    <span className="color-shade-2">Seasonal Discount:</span>
                                    <span className="text-accent-primary font-medium">
                                      -{Math.round(avgSeasonalDiscountForTooltip * 100)}%
                                    </span>
                                  </div>
                                )}
                                
                                {/* Duration Discount - Use Math.round, check hasDurationDiscount */}
                                {hasDurationDiscount && ( // Check flag
                                  <div className="flex justify-between items-center">
                                    <span className="color-shade-2">Duration Discount ({completeWeeksForDiscount} wks):</span>
                                    <span className="text-accent-primary font-medium">
                                    -{Math.round(currentDurationDiscount * 100)}%
                                    </span>
                                  </div>
                                )}

                                {/* Separator */}
                                 <div className="border-t border-gray-600 my-1"></div>

                                 {/* Final Weekly Price - Use weeklyPrice from prop, ensure not null */}
                                 <div className="flex justify-between items-center font-medium text-base">
                                    <span>Final Weekly Rate:</span>
                                    {/* Ensure weeklyPrice is not null before rounding */}
                                    <span>€{formatPrice(weeklyPrice, isTestAccommodation)}</span>
                                 </div>
                              </div>
                               <p className="text-xs color-shade-3 mt-2 font-mono">Discounts applied multiplicatively.</p>
                            </>
                          )}
                        />
                      )}
                    </div>
                  </div>

                  {/* NEW: Dedicated Border Element for Selected State */}
                  {isSelected && (
                    <div className="absolute inset-0 z-10 rounded-sm border-2 border-accent-primary pointer-events-none"></div>
                  )}
                </motion.div>
              );
            })}
          </div>
        </div>
      )}
      
      {/* Full-Screen Gallery */}
      <SimpleImageGallery
        images={galleryImages}
        isOpen={galleryOpen}
        onClose={() => {
          setGalleryOpen(false);
        }}
        title={galleryTitle}
        startIndex={galleryStartIndex}
      />
      
      {/* Accommodation Info Modal */}
      {infoModalAccommodation && (
        <AccommodationInfoModal
          isOpen={infoModalOpen}
          onClose={() => setInfoModalOpen(false)}
          title={infoModalAccommodation.title}
          propertyLocation={infoModalAccommodation.property_location}
        />
      )}
    </div>
  );
}

// Add default export
export default CabinSelector;