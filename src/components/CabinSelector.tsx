import React, { useState, useEffect, useCallback, useRef, useMemo } from 'react';
import { motion } from 'framer-motion';
import { BedDouble, Bath, Percent, Info, Ear, ChevronLeft, ChevronRight, Users, Clock } from 'lucide-react';
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
import { MasonryGallery } from './shared/MasonryGallery';
import { FullScreenMasonry } from './FullScreenMasonry';
import { TrendingDown } from 'lucide-react';
import type { AuctionPricing } from '../hooks/useDutchAuctionSimple';

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
  getPricingInfo?: (accommodationId: string) => AuctionPricing | null;
}

// Helper function to get primary image (NEW IMAGES TABLE ONLY)
const getPrimaryImageUrl = (accommodation: ExtendedAccommodation): string | null => {
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

  return (
    <div className={clsx("absolute inset-0 flex items-center justify-center p-4", `z-[${zIndex}]`)}> {/* Positioning only */}
      <div className={clsx(
        "bg-surface text-text-primary px-4 py-2 rounded-md font-mono text-sm text-center border border-border shadow-md",
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
  testMode = false,
  getPricingInfo
}: Props) {

  const { session } = useSession();
  const { isAdmin, isLoading: permissionsLoading } = useUserPermissions(session);
  const { pendingBookings } = usePendingBookings(selectedWeeks);

  // State to track current image index for each accommodation
  const [currentImageIndices, setCurrentImageIndices] = useState<Record<string, number>>({});
  // State to track loaded images to prevent alt text flash
  const [loadedImages, setLoadedImages] = useState<Set<string>>(new Set());
  // State for bathroom filters
  const [showOnlyWithBathrooms, setShowOnlyWithBathrooms] = useState(false);
  const [showOnlySharedBathrooms, setShowOnlySharedBathrooms] = useState(false);
  
  // State for masonry gallery
  const [galleryOpen, setGalleryOpen] = useState(false);
  const [galleryImages, setGalleryImages] = useState<AccommodationImage[]>([]);
  const [galleryTitle, setGalleryTitle] = useState<string>('');

  // Helper function to get current image for an accommodation
  const getCurrentImage = (accommodation: ExtendedAccommodation): string | null => {
    const allImages = getAllImages(accommodation);
    if (allImages.length === 0) return null;
    
    const currentIndex = currentImageIndices[accommodation.id] || 0;
    const validIndex = Math.min(currentIndex, allImages.length - 1);
    return allImages[validIndex]?.image_url || null;
  };

  // Navigation functions
  const navigateToImage = (accommodationId: string, direction: 'prev' | 'next', totalImages: number) => {
    setCurrentImageIndices(prev => {
      const currentIndex = prev[accommodationId] || 0;
      let newIndex;
      
      if (direction === 'next') {
        newIndex = (currentIndex + 1) % totalImages;
      } else {
        newIndex = currentIndex === 0 ? totalImages - 1 : currentIndex - 1;
      }
      
      return {
        ...prev,
        [accommodationId]: newIndex
      };
    });
  };

  const setImageIndex = (accommodationId: string, index: number) => {
    setCurrentImageIndices(prev => ({
      ...prev,
      [accommodationId]: index
    }));
  };

  // Handler to open masonry gallery
  const handleOpenGallery = (accommodation: ExtendedAccommodation, e?: React.MouseEvent) => {
    if (e) {
      e.stopPropagation();
    }
    
    const images = getAllImages(accommodation);
    
    if (images.length > 0) {
      setGalleryImages(images);
      setGalleryTitle(accommodation.title);
      setGalleryOpen(true);
    }
  };

  // Image Gallery Component
  const ImageGallery: React.FC<{ accommodation: ExtendedAccommodation }> = ({ accommodation }) => {
    const allImages = getAllImages(accommodation);
    const currentIndex = currentImageIndices[accommodation.id] || 0;
    const currentImageUrl = getCurrentImage(accommodation);
    const [imageLoading, setImageLoading] = useState(false);

    // Preload adjacent images for smoother transitions
    useEffect(() => {
      if (allImages.length > 1) {
        const nextIndex = (currentIndex + 1) % allImages.length;
        const prevIndex = currentIndex === 0 ? allImages.length - 1 : currentIndex - 1;
        
        // Preload next and previous images
        [nextIndex, prevIndex].forEach(idx => {
          const imgUrl = allImages[idx]?.image_url;
          if (imgUrl && !loadedImages.has(imgUrl)) {
            const img = new Image();
            img.onload = () => {
              setLoadedImages(prev => new Set(prev).add(imgUrl));
            };
            img.src = imgUrl;
          }
        });
      }
    }, [currentIndex, allImages]);

    if (allImages.length === 0) {
      return (
        <div className="w-full h-full flex items-center justify-center text-secondary">
          <BedDouble size={32} />
        </div>
      );
    }

    const handlePrevious = (e: React.MouseEvent) => {
      e.stopPropagation();
      setImageLoading(true);
      navigateToImage(accommodation.id, 'prev', allImages.length);
      setTimeout(() => setImageLoading(false), 50);
    };

    const handleNext = (e: React.MouseEvent) => {
      e.stopPropagation();
      setImageLoading(true);
      navigateToImage(accommodation.id, 'next', allImages.length);
      setTimeout(() => setImageLoading(false), 50);
    };

    const handleDotClick = (e: React.MouseEvent, index: number) => {
      e.stopPropagation();
      setImageLoading(true);
      setImageIndex(accommodation.id, index);
      setTimeout(() => setImageLoading(false), 50);
    };

    const handleImageLoad = () => {
      if (currentImageUrl) {
        setLoadedImages(prev => new Set(prev).add(currentImageUrl));
      }
      setImageLoading(false);
    };

    return (
      <div className="relative w-full h-full group/gallery bg-gray-100">
        {/* Main Image - clickable to open full-screen masonry */}
        <img 
          key={currentImageUrl} // Force remount for clean transitions
          src={currentImageUrl || ''} 
          alt="" // Remove alt text to prevent flash
          className={`w-full h-full object-cover group-hover:scale-105 transition-transform duration-300 ease-in-out cursor-pointer ${
            imageLoading || !loadedImages.has(currentImageUrl || '') ? 'opacity-0' : 'opacity-100'
          }`}
          onLoad={handleImageLoad}
          onClick={(e) => {
            e.stopPropagation();
            handleOpenGallery(accommodation, e);
          }}
          loading="eager" // Change to eager for gallery images
        />
        {/* Subtle expand indicator on hover */}
        <div className="absolute inset-0 bg-gradient-to-t from-black/20 to-transparent opacity-0 group-hover:opacity-100 transition-opacity duration-300 pointer-events-none" />

        {/* Navigation arrows - always visible when more than 1 image */}
        {allImages.length > 1 && (
          <>
            <button
              onClick={handlePrevious}
              className="absolute left-2 top-1/2 transform -translate-y-1/2 bg-black/80 hover:bg-black/90 text-white rounded-md p-1 transition-all duration-200 hover:scale-110 shadow-lg z-30"
              aria-label="Previous image"
            >
              <ChevronLeft size={16} />
            </button>
            <button
              onClick={handleNext}
              className="absolute right-2 top-1/2 transform -translate-y-1/2 bg-black/80 hover:bg-black/90 text-white rounded-md p-1 transition-all duration-200 hover:scale-110 shadow-lg z-30"
              aria-label="Next image"
            >
              <ChevronRight size={16} />
            </button>
          </>
        )}

        {/* Dots indicator - only show if more than 1 image */}
        {allImages.length > 1 && (
          <div className="absolute bottom-2 left-1/2 transform -translate-x-1/2 flex space-x-1 z-30">
            {allImages.map((_, index) => (
              <button
                key={index}
                onClick={(e) => handleDotClick(e, index)}
                className={clsx(
                  "w-2 h-2 rounded-full transition-all duration-200 border border-white/30",
                  index === currentIndex 
                    ? "bg-white shadow-sm scale-110" 
                    : "bg-white/30 hover:bg-white/60 hover:scale-105"
                )}
                aria-label={`Go to image ${index + 1}`}
              />
            ))}
          </div>
        )}
      </div>
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

  const handleSelectAccommodation = useCallback((id: string) => {
    // NEW: If clicking the already selected accommodation, deselect it
    if (id === selectedAccommodationId) {
      onSelectAccommodation('');
      return; // Stop further execution
    }

    // REMOVED: No longer checking availability here since useEffect[selectedWeeks] already does it
    // This was causing double API calls and state thrashing leading to flickering

    onSelectAccommodation(id);
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

  // Filter accommodations based on season and type
  const visibleAccommodations = accommodations
    .filter(acc => {
      // Filter out individual bed entries
      if ((acc as any).parent_accommodation_id) return false;

      // Filter out 'test' accommodations if the user is NOT an admin AND NOT a test user
      if (acc.type === 'test' && !canSeeTestAccommodations()) {
         return false;
      }

      // Filter by bathroom if enabled
      if (showOnlyWithBathrooms && acc.bathroom_type !== 'private') {
        return false;
      }

      // Filter by shared bathroom if enabled
      if (showOnlySharedBathrooms && acc.bathroom_type !== 'shared') {
        return false;
      }

      return true;
    })
    .sort((a, b) => {
      // Define castle location priority
      const getLocationPriority = (acc: typeof a) => {
        const location = acc.property_location;
        if (!location) return 99; // No location goes to the end
        
        // Priority order for castle locations
        switch(location) {
          case 'dovecote': return 1;      // Most exclusive
          case 'renaissance': return 2;   // Main castle building
          case 'medieval': return 3;      // Historic section
          case 'oriental': return 4;      // Exotic wing
          case 'palm_grove': return 5;    // Garden area
          default: return 99;
        }
      };
      
      // Define accommodation categories (for items without castle location)
      const getCategory = (acc: typeof a) => {
        const title = acc.title.toLowerCase();
        const type = acc.type?.toLowerCase() || '';
        
        // Category 1: Own accommodation (own tent, own van, van parking)
        if (title.includes('own tent') || title.includes('own van') || title.includes('van parking')) {
          return 100;
        }
        
        // Category 2: Camping/Tents (tipi, bell tent, other tents)
        if (type === 'tent' || title.includes('tipi') || title.includes('bell tent') || title.includes('tent')) {
          return 101;
        }
        
        // Category 3: Dorms
        if (title.includes('dorm')) {
          return 102;
        }
        
        // Category 4: All other rooms without location
        return 50;
      };
      
      const aLocPriority = getLocationPriority(a);
      const bLocPriority = getLocationPriority(b);
      
      // If both have castle locations, sort by location priority
      if (aLocPriority < 99 && bLocPriority < 99) {
        if (aLocPriority !== bLocPriority) {
          return aLocPriority - bLocPriority;
        }
        
        // Within same location, sort by floor/section if Renaissance
        if (a.property_location === 'renaissance' && b.property_location === 'renaissance') {
          const sectionOrder = { 'mezzanine': 1, 'first_floor': 2, 'second_floor': 3, 'attic': 4 };
          const aSection = sectionOrder[a.property_section as keyof typeof sectionOrder] || 5;
          const bSection = sectionOrder[b.property_section as keyof typeof sectionOrder] || 5;
          if (aSection !== bSection) return aSection - bSection;
        }
        
        // Within same location/section, sort by price
        return b.base_price - a.base_price; // Higher price first within same location
      }
      
      // If one has castle location and other doesn't, castle location comes first
      if (aLocPriority < 99) return -1;
      if (bLocPriority < 99) return 1;
      
      // If neither has castle location, use category sorting
      const aCat = getCategory(a);
      const bCat = getCategory(b);
      
      if (aCat !== bCat) {
        return aCat - bCat;
      }
      
      // Within same category, sort by price ascending
      return a.base_price - b.base_price;
    });

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
      {/* Filter options */}
      <div className="flex items-center gap-4 mb-4 flex-wrap">
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
              ({accommodations.filter(acc => acc.bathroom_type === 'private' && !(acc as any).parent_accommodation_id).length})
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
              ({accommodations.filter(acc => acc.bathroom_type === 'shared' && !(acc as any).parent_accommodation_id).length})
            </span>
          )}
        </button>
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
            {visibleAccommodations.map((acc) => {
              
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

              // Check for auction pricing first
              const auctionPricing = getPricingInfo ? getPricingInfo(acc.id) : null;
              const isInAuction = auctionPricing !== null;
              
              // Get the whole info object (regular pricing)
              const weeklyInfo = getDisplayInfoOptimized(acc.id);
              
              // Use auction price if available, otherwise use regular weekly price
              let weeklyPrice = isInAuction ? auctionPricing.currentPrice : (weeklyInfo?.price ?? null);
              const avgSeasonalDiscountForTooltip = isInAuction ? null : (weeklyInfo?.avgSeasonalDiscount ?? null);

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
              return (
                <motion.div
                  key={acc.id}
                  layout
                  initial={{ opacity: 0, scale: 0.95 }}
                  animate={{ opacity: 1, scale: 1 }}
                  transition={{ duration: 0.2 }}
                  className={clsx(
                    'relative rounded-sm overflow-hidden transition-all duration-200 flex flex-col justify-between group mb-4', // Base classes
                    // Apply bg-surface by default, override when selected, add shadow only when selected
                    isSelected 
                      ? "shadow-lg bg-[color-mix(in_srgb,_var(--color-bg-surface)_95%,_var(--color-accent-primary)_5%)]" 
                      : "bg-surface", // Use the renamed class
                    // Pointer state:
                    (testMode || (finalCanSelect && !isDisabled)) && 'cursor-pointer'
                  )}
                  onClick={(e) => {
                    // Only select accommodation if not clicking on interactive elements
                    if (testMode || (finalCanSelect && !isDisabled)) {
                      handleSelectAccommodation(acc.id);
                    }
                  }}
                  style={{ minHeight: '300px' }} 
                >
                  {/* Use the StatusOverlay helper component */}
                  <StatusOverlay isVisible={!testMode && isDisabled} zIndex={4}>
                    Select dates first
                  </StatusOverlay>
                  <StatusOverlay isVisible={!testMode && !isDisabled && isFullyBooked} zIndex={3}>
                    {pendingBookings[acc.id] && pendingBookings[acc.id].count > 0 ? 'Being booked' : 'Booked out'}
                  </StatusOverlay>
                  <StatusOverlay 
                    isVisible={!testMode && !isDisabled && isOutOfSeason && !isFullyBooked} 
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

                  {/* Image */}
                  <div className={clsx(
                    "relative h-56 overflow-hidden", // REMOVED bg-surface
                    // Apply blur and corresponding opacity/grayscale conditionally
                    !testMode && isDisabled && "blur-sm opacity-20 grayscale-[0.5]",
                    !testMode && (!isDisabled && isFullyBooked) && "blur-sm opacity-20 grayscale-[0.7]",
                    !testMode && (!isDisabled && isOutOfSeason && !isFullyBooked) && "blur-sm opacity-40 grayscale-[0.3]"
                  )}>
                    <ImageGallery accommodation={acc} />
                    <div className="absolute inset-0 bg-gradient-to-t from-black/60 to-transparent"></div> {/* Increased gradient opacity from 40% to 60% */}
                  </div>

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
                      <h3 className="text-lg font-medium mb-1 text-primary font-lettra-bold uppercase">{acc.title}</h3>
                      {/* Auction Indicator */}
                      {isInAuction && auctionPricing && (
                        <div className="mb-2 flex items-center gap-2">
                          <span className="inline-flex items-center px-2 py-1 rounded-sm text-xs font-medium bg-green-900/20 text-green-200 border border-green-700/30">
                            <TrendingDown size={12} className="mr-1" />
                            Dutch Auction - drops €{auctionPricing.dailyDrop}/day
                          </span>
                        </div>
                      )}
                      {/* Property Location Badge */}
                      {acc.property_location && (
                        <div className="mb-2">
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
                        </div>
                      )}
                      {/* Additional Info - Display as formatted text with icons */}
                      {acc.additional_info && (
                        <div className="text-secondary text-xs mb-3 space-y-1">
                          {acc.additional_info.split('•').map((info, idx) => {
                            const trimmedInfo = info.trim();
                            if (!trimmedInfo) return null;
                            
                            // Add icons for specific amenities
                            let icon = null;
                            if (trimmedInfo.toLowerCase().includes('bed')) {
                              icon = <BedDouble size={12} className="inline mr-1" />;
                            } else if (trimmedInfo.toLowerCase().includes('bath')) {
                              icon = <Bath size={12} className="inline mr-1" />;
                            }
                            
                            return (
                              <div key={idx} className="flex items-start">
                                <span className="mr-1">•</span>
                                <span>
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
      
      {/* Full-Screen Masonry Gallery */}
      <FullScreenMasonry
        images={galleryImages}
        isOpen={galleryOpen}
        onClose={() => setGalleryOpen(false)}
        title={galleryTitle}
      />
    </div>
  );
}

// Add default export
export default CabinSelector;