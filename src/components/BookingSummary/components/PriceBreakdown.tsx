import React from 'react';
import { Info } from 'lucide-react';
import * as Tooltip from '@radix-ui/react-tooltip';
import { HoverClickPopover } from '../../HoverClickPopover';
import { formatPriceDisplay, formatNumber, calculateFoodContributionRange } from '../BookingSummary.utils';
import { OptimizedSlider } from '../../shared/OptimizedSlider';
import type { Accommodation } from '../../../types';
import type { PricingDetails } from '../BookingSummary.types';

interface PriceBreakdownProps {
  selectedAccommodation: Accommodation | null;
  pricing: PricingDetails;
  foodContribution: number | null;
  setFoodContribution: (value: number | null) => void;
  isStateOfTheArtist: boolean;
  selectedWeeks: any[]; // Using any to avoid importing Week type
  onShowDiscountModal: () => void;
}

export function PriceBreakdown({
  selectedAccommodation,
  pricing,
  foodContribution,
  setFoodContribution,
  isStateOfTheArtist,
  selectedWeeks,
  onShowDiscountModal
}: PriceBreakdownProps) {
  // Local state for immediate slider feedback
  const [displayFoodContribution, setDisplayFoodContribution] = React.useState<number | null>(null);
  const isDraggingRef = React.useRef(false);
  
  // Calculate food contribution range with duration discount applied
  const foodRange = React.useMemo(() => {
    if (isStateOfTheArtist) {
      // Special case for State of the Artist event
      return { min: 390, max: 3600, defaultValue: 390 };
    }
    return calculateFoodContributionRange(pricing.totalNights, pricing.durationDiscountPercent / 100);
  }, [isStateOfTheArtist, pricing.totalNights, pricing.durationDiscountPercent]);
  
  // Sync display value with actual value only when not dragging
  React.useEffect(() => {
    if (!isDraggingRef.current) {
      setDisplayFoodContribution(foodContribution);
    }
  }, [foodContribution]);
  
  // Handle display value changes during drag
  const handleDisplayValueChange = React.useCallback((value: number) => {
    isDraggingRef.current = true;
    // Ensure value is within bounds
    const clampedValue = Math.max(foodRange.min, Math.min(foodRange.max, value));
    setDisplayFoodContribution(clampedValue);
    
    // Reset dragging flag shortly after (but don't reset display value)
    setTimeout(() => {
      isDraggingRef.current = false;
    }, 200);
  }, [foodRange.min, foodRange.max]);
  
  console.log('[BookingSummary] Slider Range with duration discount:', { 
    foodRange, 
    isStateOfTheArtist, 
    durationDiscountPercent: pricing.durationDiscountPercent + '%'
  });

  return (
    <div>
      <div className="flex items-center justify-between mb-3">
        {/* Restyle heading to match accommodation title */}
        <h3 className="text-primary font-display text-2xl block">Price breakdown</h3>
        <Tooltip.Provider>
          <Tooltip.Root delayDuration={50}>
            <Tooltip.Trigger asChild>
              <button
                onClick={(e) => {
                  e.stopPropagation(); // Prevent event bubbling
                  onShowDiscountModal();
                }}
                className="p-1.5 text-[var(--color-accent-primary)] hover:text-[var(--color-accent-secondary)] rounded-md transition-colors cursor-pointer"
              >
                <Info className="w-4 h-4" />
                <span className="sr-only">View Discount Details</span>
              </button>
            </Tooltip.Trigger>
            <Tooltip.Portal>
              <Tooltip.Content
                className="tooltip-content !font-mono z-50"
                sideOffset={5}
              >
                Click for detailed breakdown
                <Tooltip.Arrow className="tooltip-arrow" />
              </Tooltip.Content>
            </Tooltip.Portal>
          </Tooltip.Root>
        </Tooltip.Provider>
      </div>
      
      <div className="bg-surface space-y-4 p-4 rounded-sm"> {/* Increased spacing between items */}
        {selectedAccommodation ? (
          <>
            <div className="flex justify-between items-center"> {/* Simplified flex */}
              <span className="text-lg text-primary font-display">Accommodation</span>
              {/* Price: Make it larger and more prominent */}
              <span className="text-2xl font-display text-primary">{formatPriceDisplay(pricing.totalAccommodationCost)}</span>
            </div>
          </>
        ) : (
          <div className="flex items-baseline min-h-[1.25rem]">
            <span className="text-sm text-secondary font-mono italic">No accommodation selected</span>
          </div>
        )}
        
      </div>
    </div>
  );
}