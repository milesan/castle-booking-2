import React, { useState, useMemo } from 'react';
import { MapPin, Calendar, Plane, Info } from 'lucide-react';
import { format, addDays } from 'date-fns';
import { motion, AnimatePresence } from 'framer-motion';

interface GardenDecompressionOption {
  id: string;
  name: string;
  startDate: Date;
  endDate: Date;
  price: number;
  description: string;
}

interface GardenDecompressionAddonProps {
  castleEndDate: Date; // September 26, 2025
  onSelectAddon: (option: GardenDecompressionOption | null) => void;
  selectedAddon: GardenDecompressionOption | null;
}

export function GardenDecompressionAddon({ 
  castleEndDate, 
  onSelectAddon,
  selectedAddon 
}: GardenDecompressionAddonProps) {
  const [showTravelInfo, setShowTravelInfo] = useState(false);

  // Define the decompression options
  const decompressionOptions: GardenDecompressionOption[] = useMemo(() => {
    const sept26 = castleEndDate;
    const sept29 = addDays(sept26, 3);
    const sept30 = addDays(sept26, 4);
    const oct6 = addDays(sept26, 10);

    return [
      {
        id: 'weekend',
        name: 'Weekend Decompression',
        startDate: sept26,
        endDate: sept29,
        price: 125,
        description: 'Fri-Mon • 3 nights of gentle re-entry'
      },
      {
        id: 'full-week',
        name: 'Full Week Decompression',
        startDate: sept26,
        endDate: oct6,
        price: 400,
        description: 'Fri-Sun • 10 nights of deep integration'
      },
      {
        id: 'october-week',
        name: 'October Week',
        startDate: sept30,
        endDate: oct6,
        price: 275,
        description: 'Mon-Sun • 7 nights starting after the weekend'
      }
    ];
  }, [castleEndDate]);

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
    <div className="rounded-sm shadow-sm py-3 xs:py-4 sm:py-6 mb-4 xs:mb-5 sm:mb-6">
      <div className="flex flex-col gap-3 mb-4">
        <div className="flex items-center gap-2 mb-2">
          <h3 className="text-xl sm:text-2xl font-display font-light text-primary">
            Garden Decompression
          </h3>
          <span className="bg-gray-100 text-gray-600 px-2 py-1 rounded-sm text-xs font-mono uppercase tracking-wide">
            Optional
          </span>
        </div>
        <p className="text-sm sm:text-base text-secondary font-mono">
          Decompress after The Castle at our permanent campus in Portugal
        </p>
        <p className="text-xs text-secondary font-mono italic">
          You can proceed without selecting any decompression option.
        </p>
      </div>

      {/* Options Grid */}
      <div className="grid grid-cols-1 md:grid-cols-3 gap-3 mb-4">
        {decompressionOptions.map((option) => {
          const isSelected = selectedAddon?.id === option.id;
          
          return (
            <motion.button
              key={option.id}
              onClick={() => onSelectAddon(isSelected ? null : option)}
              className={`
                relative p-4 rounded-sm border-2 transition-all duration-200
                ${isSelected 
                  ? 'border-accent-primary bg-accent-primary/10' 
                  : 'border-border hover:border-accent-primary/50 bg-surface/50'
                }
              `}
              whileHover={{ scale: 1.02 }}
              whileTap={{ scale: 0.98 }}
            >
              {/* Selected indicator */}
              {isSelected && (
                <div className="absolute top-2 right-2">
                  <div className="w-6 h-6 rounded-full bg-accent-primary flex items-center justify-center">
                    <svg className="w-4 h-4 text-white" fill="none" viewBox="0 0 24 24" stroke="currentColor">
                      <path strokeLinecap="round" strokeLinejoin="round" strokeWidth={2} d="M5 13l4 4L19 7" />
                    </svg>
                  </div>
                </div>
              )}

              <div className="text-left">
                <h3 className="font-display text-lg text-primary mb-1">
                  {option.name}
                </h3>
                <p className="text-xs text-secondary mb-2 font-mono">
                  {option.description}
                </p>
                <div className="flex items-center gap-2 text-sm text-secondary mb-2">
                  <Calendar className="w-4 h-4" />
                  <span>{formatDateRange(option.startDate, option.endDate)}</span>
                </div>
                <div className="text-xl font-display text-primary">
                  €{option.price}
                </div>
              </div>
            </motion.button>
          );
        })}
      </div>

      {/* Travel Information */}
      <div className="border-t border-border pt-4">
        <button
          onClick={() => setShowTravelInfo(!showTravelInfo)}
          className="flex items-center gap-2 text-sm text-secondary hover:text-primary transition-colors font-mono"
        >
          <Info className="w-4 h-4" />
          <span>Travel Information</span>
          <svg
            className={`w-4 h-4 transition-transform ${showTravelInfo ? 'rotate-180' : ''}`}
            fill="none"
            viewBox="0 0 24 24"
            stroke="currentColor"
          >
            <path strokeLinecap="round" strokeLinejoin="round" strokeWidth={2} d="M19 9l-7 7-7-7" />
          </svg>
        </button>

        <AnimatePresence>
          {showTravelInfo && (
            <motion.div
              initial={{ height: 0, opacity: 0 }}
              animate={{ height: 'auto', opacity: 1 }}
              exit={{ height: 0, opacity: 0 }}
              transition={{ duration: 0.2 }}
              className="overflow-hidden"
            >
              <div className="mt-4 p-4 bg-surface/50 rounded-sm space-y-3">
                <div className="flex items-start gap-3">
                  <MapPin className="w-5 h-5 text-accent-primary mt-0.5 flex-shrink-0" />
                  <div>
                    <h4 className="font-display text-primary mb-1">Location</h4>
                    <p className="text-sm text-secondary font-mono">
                      The Garden is located in Northern Portugal, 45 minutes from Porto
                    </p>
                    <a 
                      href="https://thegarden.pt" 
                      target="_blank" 
                      rel="noopener noreferrer"
                      className="text-sm text-accent-primary hover:underline font-mono mt-1 inline-block"
                    >
                      Visit The Garden website →
                    </a>
                  </div>
                </div>

                <div className="flex items-start gap-3">
                  <Plane className="w-5 h-5 text-accent-primary mt-0.5 flex-shrink-0" />
                  <div>
                    <h4 className="font-display text-primary mb-1">How to Get There</h4>
                    <ol className="text-sm text-secondary font-mono space-y-1">
                      <li>1. Uber from the Castle to Paris Orly Airport (ORY)</li>
                      <li>2. Fly 2 hours to Porto Airport (OPO)</li>
                      <li>3. Uber 45 minutes to The Garden</li>
                      <li className="text-accent-primary">→ Rideshares will be organized in the community</li>
                    </ol>
                  </div>
                </div>

                <div className="text-xs text-secondary font-mono italic">
                  Note: The Garden decompression is a separate booking from The Castle. 
                  You'll receive separate confirmation and check-in instructions.
                </div>
              </div>
            </motion.div>
          )}
        </AnimatePresence>
      </div>

      {/* Selected addon summary */}
      {selectedAddon && (
        <motion.div
          initial={{ opacity: 0, y: -10 }}
          animate={{ opacity: 1, y: 0 }}
          className="mt-4 p-3 bg-accent-primary/10 rounded-sm border border-accent-primary/30"
        >
          <div className="flex items-center justify-between">
            <div className="flex items-center gap-2">
              <div className="w-2 h-2 rounded-full bg-accent-primary animate-pulse" />
              <span className="text-sm font-mono text-primary">
                Garden Decompression Added: {selectedAddon.name}
              </span>
            </div>
            <button
              onClick={() => onSelectAddon(null)}
              className="text-xs text-secondary hover:text-primary font-mono"
            >
              Remove
            </button>
          </div>
        </motion.div>
      )}
    </div>
  );
}