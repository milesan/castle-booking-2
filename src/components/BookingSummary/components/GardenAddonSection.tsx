import React from 'react';
import { X, MapPin, Calendar } from 'lucide-react';
import { format } from 'date-fns';
import { formatPriceDisplay } from '../BookingSummary.utils';
import type { GardenAddon } from '../BookingSummary.types';

interface GardenAddonSectionProps {
  gardenAddon: GardenAddon;
  onClearGardenAddon?: () => void;
}

export function GardenAddonSection({ gardenAddon, onClearGardenAddon }: GardenAddonSectionProps) {
  const formatDateRange = (start: Date, end: Date) => {
    const startMonth = format(start, 'MMM');
    const endMonth = format(end, 'MMM');
    const startDay = format(start, 'd');
    const endDay = format(end, 'd');
    
    if (startMonth === endMonth) {
      return `${startMonth} ${startDay}-${endDay}`;
    }
    return `${startMonth} ${startDay} - ${endMonth} ${endDay}`;
  };

  return (
    <div className="mt-6 p-4 bg-surface/50 rounded-sm border border-accent-primary/30">
      <div className="flex justify-between items-start mb-3">
        <div className="flex items-center gap-2">
          <MapPin className="w-5 h-5 text-accent-primary" />
          <h3 className="font-display text-lg text-primary">Garden Decompression</h3>
        </div>
        {onClearGardenAddon && (
          <button
            onClick={onClearGardenAddon}
            className="text-secondary hover:text-primary transition-colors"
          >
            <X className="w-4 h-4" />
          </button>
        )}
      </div>
      
      <div className="space-y-2">
        <div className="flex items-center gap-2 text-sm text-secondary">
          <Calendar className="w-4 h-4" />
          <span className="font-mono">{formatDateRange(gardenAddon.startDate, gardenAddon.endDate)}</span>
        </div>
        
        <div className="flex justify-between items-center">
          <span className="text-sm text-secondary font-mono">{gardenAddon.name}</span>
          <span className="font-display text-lg text-primary">
            {formatPriceDisplay(gardenAddon.price)}
          </span>
        </div>
        
        <div className="mt-3 pt-3 border-t border-border">
          <p className="text-xs text-secondary font-mono italic">
            Includes accommodation at The Garden in Portugal
          </p>
        </div>
      </div>
    </div>
  );
}