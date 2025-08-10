import React, { useEffect, useCallback } from 'react';
import { motion, AnimatePresence } from 'framer-motion';
import { X } from 'lucide-react';

interface AccommodationImage {
  id: string;
  accommodation_id: string;
  image_url: string;
  display_order: number;
  is_primary: boolean;
  created_at: string;
}

interface Props {
  images: AccommodationImage[];
  isOpen: boolean;
  onClose: () => void;
  title: string;
}

export function FullScreenMasonry({ images, isOpen, onClose, title }: Props) {
  // Handle escape key
  useEffect(() => {
    const handleEscape = (e: KeyboardEvent) => {
      if (e.key === 'Escape' && isOpen) {
        onClose();
      }
    };

    if (isOpen) {
      document.addEventListener('keydown', handleEscape);
      // Prevent body scroll when open
      document.body.style.overflow = 'hidden';
    }

    return () => {
      document.removeEventListener('keydown', handleEscape);
      document.body.style.overflow = '';
    };
  }, [isOpen, onClose]);

  // Memoized click handler for backdrop
  const handleBackdropClick = useCallback((e: React.MouseEvent) => {
    // Close on any click
    onClose();
  }, [onClose]);

  if (!isOpen) return null;

  // Group images into columns for masonry effect
  const columns = 3; // Desktop columns
  const imageColumns: AccommodationImage[][] = Array.from({ length: columns }, () => []);
  
  images.forEach((img, idx) => {
    imageColumns[idx % columns].push(img);
  });

  return (
    <AnimatePresence>
      {isOpen && (
        <motion.div
          initial={{ opacity: 0 }}
          animate={{ opacity: 1 }}
          exit={{ opacity: 0 }}
          transition={{ duration: 0.2 }}
          className="fixed inset-0 z-[9999] bg-black/95 backdrop-blur-sm"
          onClick={handleBackdropClick}
        >
          {/* Close button - minimal, top right */}
          <button
            className="absolute top-6 right-6 z-[10000] text-white/60 hover:text-white transition-colors duration-200"
            onClick={onClose}
            aria-label="Close gallery"
          >
            <X size={24} />
          </button>

          {/* Title - minimal, centered */}
          <div className="absolute top-6 left-1/2 transform -translate-x-1/2 z-[10000]">
            <h2 className="text-white/80 font-lettra-bold uppercase text-sm tracking-wider">
              {title}
            </h2>
          </div>

          {/* Masonry Grid Container */}
          <div className="h-full w-full overflow-y-auto p-8 pt-20">
            <motion.div
              initial={{ scale: 0.95, opacity: 0 }}
              animate={{ scale: 1, opacity: 1 }}
              transition={{ duration: 0.3, delay: 0.1 }}
              className="max-w-7xl mx-auto"
            >
              <div className="grid grid-cols-1 md:grid-cols-2 lg:grid-cols-3 gap-4">
                {imageColumns.map((column, colIdx) => (
                  <div key={colIdx} className="flex flex-col gap-4">
                    {column.map((img, imgIdx) => (
                      <motion.div
                        key={img.id}
                        initial={{ opacity: 0, y: 20 }}
                        animate={{ opacity: 1, y: 0 }}
                        transition={{ 
                          duration: 0.3, 
                          delay: 0.05 * (colIdx * 3 + imgIdx) 
                        }}
                        className="relative group cursor-pointer"
                        onClick={handleBackdropClick}
                      >
                        <img
                          src={img.image_url}
                          alt=""
                          className="w-full h-auto rounded-sm transition-all duration-300 hover:brightness-110"
                          loading="lazy"
                        />
                        {/* Subtle hover overlay */}
                        <div className="absolute inset-0 bg-white/5 opacity-0 group-hover:opacity-100 transition-opacity duration-300 rounded-sm pointer-events-none" />
                      </motion.div>
                    ))}
                  </div>
                ))}
              </div>
            </motion.div>
          </div>

          {/* Bottom hint - minimal */}
          <div className="absolute bottom-6 left-1/2 transform -translate-x-1/2 z-[10000]">
            <p className="text-white/40 text-xs font-mono">
              Click anywhere to close
            </p>
          </div>
        </motion.div>
      )}
    </AnimatePresence>
  );
}