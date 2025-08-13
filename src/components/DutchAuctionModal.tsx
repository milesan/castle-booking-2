import React, { useEffect, useState } from 'react';
import { X, Flower } from 'lucide-react';
import { motion, AnimatePresence } from 'framer-motion';
import { supabase } from '../lib/supabase';

interface DutchAuctionModalProps {
  userId?: string;
}

export function DutchAuctionModal({ userId }: DutchAuctionModalProps) {
  const [isOpen, setIsOpen] = useState(false);
  const [hasSeenModal, setHasSeenModal] = useState(false);

  useEffect(() => {
    const checkIfFirstLogin = async () => {
      if (!userId) return;

      // Check localStorage first for quick check
      const localStorageKey = `dutch-auction-seen-${userId}`;
      const hasSeenLocally = localStorage.getItem(localStorageKey);
      
      if (hasSeenLocally) {
        setHasSeenModal(true);
        return;
      }

      // Check database for persistent storage across devices
      const { data, error } = await supabase
        .from('user_preferences')
        .select('has_seen_dutch_auction_modal')
        .eq('user_id', userId)
        .single();

      if (error && error.code !== 'PGRST116') {
        // PGRST116 means no rows returned, which is fine for first-time users
        console.error('Error checking modal preference:', error);
        return;
      }

      if (!data || !data.has_seen_dutch_auction_modal) {
        // First login - show the modal
        setIsOpen(true);
      } else {
        setHasSeenModal(true);
        localStorage.setItem(localStorageKey, 'true');
      }
    };

    checkIfFirstLogin();
  }, [userId]);

  const handleClose = async () => {
    setIsOpen(false);
    setHasSeenModal(true);

    if (!userId) return;

    // Save to localStorage for quick future checks
    const localStorageKey = `dutch-auction-seen-${userId}`;
    localStorage.setItem(localStorageKey, 'true');

    // Save to database for persistence
    try {
      await supabase
        .from('user_preferences')
        .upsert({
          user_id: userId,
          has_seen_dutch_auction_modal: true,
          updated_at: new Date().toISOString()
        }, {
          onConflict: 'user_id'
        });
    } catch (error) {
      console.error('Error saving modal preference:', error);
    }
  };

  if (hasSeenModal || !isOpen) return null;

  return (
    <AnimatePresence>
      {isOpen && (
        <motion.div
          initial={{ opacity: 0 }}
          animate={{ opacity: 1 }}
          exit={{ opacity: 0 }}
          className="fixed inset-0 z-50 flex items-center justify-center p-4 bg-black/60 backdrop-blur-sm"
          onClick={handleClose}
        >
          <motion.div
            initial={{ scale: 0.9, opacity: 0 }}
            animate={{ scale: 1, opacity: 1 }}
            exit={{ scale: 0.9, opacity: 0 }}
            transition={{ type: "spring", duration: 0.5 }}
            className="relative max-w-md w-full bg-surface border border-border rounded-sm p-8 shadow-2xl"
            onClick={(e) => e.stopPropagation()}
          >
            {/* Close button */}
            <button
              onClick={handleClose}
              className="absolute top-4 right-4 text-secondary hover:text-primary transition-colors"
              aria-label="Close"
            >
              <X size={20} />
            </button>

            {/* Flower icon */}
            <div className="flex justify-center mb-6">
              <div className="p-3 bg-accent-primary/10 rounded-full">
                <Flower size={32} className="text-accent-primary" />
              </div>
            </div>

            {/* Content */}
            <div className="space-y-4 text-center">
              <h2 className="text-xl font-medium text-primary">Dutch Flower Auction</h2>
              
              <div className="space-y-3 text-secondary text-sm">
                <p>
                  Rooms are to be acquired via a dutch flower auction. 
                  This is my favourite kind of auction.
                </p>
                
                <p className="font-medium text-primary">
                  How it works:
                </p>
                
                <p>
                  Once a day, every day, the prices for all rooms will fall by a fixed amount.
                </p>
                
                <p>
                  Anyone may purchase any room at any time.
                </p>
                
                <p>
                  There are 3 tiers of rooms, each with their own starting price and floor.
                </p>
                
                <p className="text-accent-primary pt-2">
                  Have fun ♥
                </p>
              </div>

              {/* Acknowledge button */}
              <button
                onClick={handleClose}
                className="mt-6 px-6 py-2 bg-accent-primary text-white rounded-sm hover:bg-accent-primary/90 transition-colors text-sm font-medium"
              >
                Let's go
              </button>
            </div>
          </motion.div>
        </motion.div>
      )}
    </AnimatePresence>
  );
}