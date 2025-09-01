import React from 'react';
import { X, Clock, MapPin, Info } from 'lucide-react';
import { motion, AnimatePresence } from 'framer-motion';

interface AccommodationInfoModalProps {
  isOpen: boolean;
  onClose: () => void;
  title: string;
  propertyLocation?: string | null;
}

const getCheckInOutInfo = (title: string, propertyLocation?: string | null) => {
  const lowerTitle = title.toLowerCase();
  
  // Castle Rooms (Renaissance, Dovecote, Oriental, Medieval, Palm Grove)
  if (propertyLocation && ['renaissance', 'dovecote', 'oriental', 'medieval', 'palm_grove'].includes(propertyLocation)) {
    return {
      checkIn: '4pm on 21st',
      checkOut: '11:30am on 26th',
      notes: null
    };
  }
  
  // Le Dorm
  if (lowerTitle === 'le dorm') {
    return {
      checkIn: '4pm on 21st',
      checkOut: '11:30am on 26th',
      notes: null
    };
  }
  
  // Castle Glamping (Microcabin, Yurt, A-Frame) - VIEW OF CHATEAU
  if (lowerTitle.includes('microcabin') || lowerTitle.includes('yurt') || lowerTitle.includes('a-frame')) {
    return {
      checkIn: '4pm on 21st',
      checkOut: '9am on 26th',
      notes: 'View of Chateau. Early checkout required: We only have 3 hours to tear down the tents as a wedding party will be setting up, so it is very important that people checkout on time.',
      type: 'Castle Glamping'
    };
  }
  
  // Castle Grounds & Ramparts Glamping - AVAILABLE BY 4PM - MUST CHECK OUT BY 9AM
  if (lowerTitle.includes('castle view') || lowerTitle.includes('near castle') || lowerTitle.includes('rampart')) {
    return {
      checkIn: '4pm on 21st',
      checkOut: '9am on 26th',
      notes: lowerTitle.includes('rampart') ? 'Ramparts view location. Available from 4pm. Early checkout required: We only have 3 hours to tear down the tents as a wedding party will be setting up, so it is very important that people checkout on time.' : 'Castle grounds location. Available from 4pm. Early checkout required: We only have 3 hours to tear down the tents as a wedding party will be setting up, so it is very important that people checkout on time.',
      type: lowerTitle.includes('bell tent') ? 'Castle Grounds Bell Tent' : 'Ramparts View Tipi'
    };
  }
  
  // Valley Gardens Glamping & Single Tipi - AVAILABLE BY 9PM (AFTER OPENING CEREMONY)
  if (lowerTitle.includes('single tipi') || (lowerTitle.includes('garden') && (lowerTitle.includes('tipi') || lowerTitle.includes('bell tent')))) {
    return {
      checkIn: '9pm on 21st',
      checkOut: '11:30am on 26th',
      notes: 'Valley Gardens location. Available from 9pm. We will take your bags and put them directly in your accommodation when ready.',
      type: lowerTitle.includes('single tipi') ? 'Single Tipi (Valley Gardens)' : 'Valley Gardens Glamping'
    };
  }
  
  // Standard Bell Tent (if not castle/garden specific)
  if (lowerTitle.includes('bell tent')) {
    return {
      checkIn: '4pm on 21st',
      checkOut: '9am on 26th',
      notes: 'Available from 4pm. Early checkout required: We only have 3 hours to tear down the tents as a wedding party will be setting up, so it is very important that people checkout on time.',
      type: '4m Bell Tent'
    };
  }
  
  // Standard Tipi (if not already caught)
  if (lowerTitle.includes('tipi')) {
    return {
      checkIn: '9pm on 21st',
      checkOut: '11:30am on 26th',
      notes: 'Valley gardens location. Available from 9pm.',
      type: 'Tipi'
    };
  }
  
  // Your Own Van / DIY Van - 5PM CHECK-IN
  if (lowerTitle.includes('own van') || lowerTitle.includes('van parking') || lowerTitle.includes('your own van') || lowerTitle.includes('diy van')) {
    return {
      checkIn: '5pm on 21st',
      checkOut: '3pm on 26th',
      notes: 'Valley Gardens location. Located in secure compound with 24-hour security, 2 min walk from Chateau.',
      type: lowerTitle.includes('diy') ? 'DIY Van' : 'Your Own Van'
    };
  }
  
  // Your Own Tent / DIY Tent - 5PM CHECK-IN
  if (lowerTitle.includes('own tent') || lowerTitle.includes('your own tent') || lowerTitle.includes('diy tent')) {
    return {
      checkIn: '5pm on 21st',
      checkOut: '3pm on 26th',
      notes: 'Valley Gardens location. Located in secure compound with 24-hour security, 2 min walk from Chateau.',
      type: lowerTitle.includes('diy') ? 'DIY Tent' : 'Your Own Tent'
    };
  }
  
  // Default (shouldn't happen, but just in case)
  return {
    checkIn: '4pm on 21st',
    checkOut: '11:30am on 26th',
    notes: null
  };
};

export function AccommodationInfoModal({ isOpen, onClose, title, propertyLocation }: AccommodationInfoModalProps) {
  const info = getCheckInOutInfo(title, propertyLocation);
  
  return (
    <AnimatePresence>
      {isOpen && (
        <>
          {/* Backdrop */}
          <motion.div
            initial={{ opacity: 0 }}
            animate={{ opacity: 1 }}
            exit={{ opacity: 0 }}
            onClick={onClose}
            className="fixed inset-0 bg-black/60 backdrop-blur-sm z-[100]"
          />
          
          {/* Modal - Fullscreen on mobile, centered on desktop */}
          <motion.div
            initial={{ opacity: 0, scale: 0.95, y: 20 }}
            animate={{ opacity: 1, scale: 1, y: 0 }}
            exit={{ opacity: 0, scale: 0.95, y: 20 }}
            className="fixed inset-4 md:inset-auto md:left-1/2 md:top-1/2 md:-translate-x-1/2 md:-translate-y-1/2 z-[101] md:w-[90%] md:max-w-md max-h-[calc(100vh-2rem)] md:max-h-[90vh] overflow-y-auto"
          >
            <div className="bg-surface border border-border rounded-sm shadow-2xl h-full md:h-auto flex flex-col">
              {/* Header */}
              <div className="flex items-center justify-between p-4 border-b border-border">
                <h2 className="text-lg font-lettra-bold uppercase text-primary">
                  {info.type || title}
                </h2>
                <button
                  onClick={onClose}
                  className="p-1 hover:bg-surface-hover rounded-sm transition-colors"
                  aria-label="Close modal"
                >
                  <X size={20} className="text-secondary" />
                </button>
              </div>
              
              {/* Content */}
              <div className="p-4 space-y-4 flex-1 overflow-y-auto">
                {/* Check-in Time */}
                <div className="flex items-start gap-3">
                  <Clock size={20} className="text-accent-primary mt-0.5" />
                  <div>
                    <div className="text-sm font-medium text-primary mb-1">Check-in</div>
                    <div className="text-base text-primary font-mono">{info.checkIn}</div>
                  </div>
                </div>
                
                {/* Check-out Time */}
                <div className="flex items-start gap-3">
                  <Clock size={20} className="text-accent-primary mt-0.5" />
                  <div>
                    <div className="text-sm font-medium text-primary mb-1">Check-out</div>
                    <div className="text-base text-primary font-mono">{info.checkOut}</div>
                  </div>
                </div>
                
                {/* Special Notes */}
                {info.notes && (
                  <div className="mt-4 p-3 bg-amber-900/20 border border-amber-700/30 rounded-sm">
                    <div className="flex items-start gap-2">
                      <Info size={18} className="text-amber-500 mt-0.5 flex-shrink-0" />
                      <p className="text-sm text-amber-200 leading-relaxed">
                        {info.notes}
                      </p>
                    </div>
                  </div>
                )}
                
                {/* General Info */}
                <div className="mt-4 pt-4 border-t border-border">
                  <p className="text-xs text-secondary leading-relaxed">
                    This information is vital for a smooth castle week experience. 
                    Please ensure you adhere to these times to avoid any inconvenience.
                  </p>
                </div>
              </div>
              
              {/* Footer with Okay button */}
              <div className="p-4 border-t border-border">
                <button
                  onClick={onClose}
                  className="w-full py-2 px-4 bg-accent-primary hover:bg-accent-secondary text-white font-medium rounded-sm transition-colors"
                >
                  Okay!
                </button>
              </div>
            </div>
          </motion.div>
        </>
      )}
    </AnimatePresence>
  );
}