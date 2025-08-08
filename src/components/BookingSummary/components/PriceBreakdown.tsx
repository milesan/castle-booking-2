import React from 'react';
import { Info } from 'lucide-react';
import { HoverClickPopover } from '../../HoverClickPopover';
import { formatPriceDisplay, formatNumber } from '../BookingSummary.utils';
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
}

export function PriceBreakdown({
  selectedAccommodation,
  pricing,
  foodContribution,
  setFoodContribution,
  isStateOfTheArtist,
  selectedWeeks
}: PriceBreakdownProps) {
  // No food contribution or discounts in simplified version

  return (
    <div>
      <div className="mb-3">
        {/* Simple heading without tooltip */}
        <h3 className="text-primary font-display text-2xl block">Price breakdown</h3>
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