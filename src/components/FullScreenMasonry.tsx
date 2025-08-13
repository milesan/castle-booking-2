import React, { useEffect, useCallback, useState } from 'react';
import { motion, AnimatePresence } from 'framer-motion';
import { X, ChevronLeft, ChevronRight } from 'lucide-react';

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
  const [currentImageIndex, setCurrentImageIndex] = useState(0);
  const [viewMode, setViewMode] = useState<'masonry' | 'single'>('single'); // Start with single image view
  
  // Reset when opening
  useEffect(() => {
    if (isOpen) {
      setCurrentImageIndex(0);
      setViewMode('single');
    }
  }, [isOpen, images.length]);

  // Navigation handlers (moved before useEffect to fix dependency issue)
  const handlePrevious = useCallback(() => {
    setCurrentImageIndex(prev => prev === 0 ? images.length - 1 : prev - 1);
  }, [images.length]);

  const handleNext = useCallback(() => {
    setCurrentImageIndex(prev => (prev + 1) % images.length);
  }, [images.length]);

  // Handle escape key and arrow keys
  useEffect(() => {
    const handleKeyPress = (e: KeyboardEvent) => {
      if (!isOpen) return;
      
      if (e.key === 'Escape') {
        onClose();
      } else if (e.key === 'ArrowLeft') {
        handlePrevious();
      } else if (e.key === 'ArrowRight') {
        handleNext();
      } else if (e.key === 'g' || e.key === 'G') {
        // Toggle between masonry and single view
        setViewMode(prev => prev === 'masonry' ? 'single' : 'masonry');
      }
    };

    if (isOpen) {
      document.addEventListener('keydown', handleKeyPress);
      // Prevent body scroll when open
      document.body.style.overflow = 'hidden';
    }

    return () => {
      document.removeEventListener('keydown', handleKeyPress);
      document.body.style.overflow = '';
    };
  }, [isOpen, onClose, handlePrevious, handleNext]);

  // Memoized click handler for backdrop
  const handleBackdropClick = useCallback((e: React.MouseEvent) => {
    // Only close if clicking the backdrop, not the content
    if (e.target === e.currentTarget) {
      onClose();
    }
  }, [onClose]);

  if (!isOpen || images.length === 0) {
    return null;
  }

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
            className="absolute top-6 right-6 z-[10001] text-white/60 hover:text-white transition-colors duration-200"
            onClick={(e) => {
              e.stopPropagation();
              onClose();
            }}
            aria-label="Close gallery"
          >
            <X size={28} />
          </button>

          {/* Title and view toggle - minimal, centered */}
          <div className="absolute top-6 left-1/2 transform -translate-x-1/2 z-[10001] text-center">
            <h2 className="text-white/80 font-lettra-bold uppercase text-sm tracking-wider">
              {title}
            </h2>
            <button 
              onClick={(e) => {
                e.stopPropagation();
                setViewMode(prev => prev === 'masonry' ? 'single' : 'masonry');
              }}
              className="text-white/40 hover:text-white/60 text-xs mt-1 transition-colors"
            >
              {viewMode === 'single' ? 'View Grid' : 'View Single'} (G)
            </button>
          </div>

          {/* Content Container */}
          <div className="h-full w-full overflow-y-auto p-8 pt-20">
            {viewMode === 'single' ? (
              // Single image view with navigation
              <motion.div
                key="single-view"
                initial={{ scale: 0.95, opacity: 0 }}
                animate={{ scale: 1, opacity: 1 }}
                transition={{ duration: 0.3, delay: 0.1 }}
                className="h-full flex items-center justify-center"
              >
                <div className="relative max-w-[90vw] max-h-[85vh]">
                  <img
                    src={images[currentImageIndex].image_url}
                    alt=""
                    className="max-w-full max-h-[85vh] object-contain rounded-sm"
                    loading="eager"
                  />
                  
                  {/* Navigation arrows */}
                  {images.length > 1 && (
                    <>
                      <button
                        onClick={(e) => {
                          e.stopPropagation();
                          handlePrevious();
                        }}
                        className="absolute left-4 top-1/2 transform -translate-y-1/2 bg-black/60 hover:bg-black/80 text-white rounded-full p-3 transition-all duration-200 hover:scale-110"
                        aria-label="Previous image"
                      >
                        <ChevronLeft size={24} />
                      </button>
                      <button
                        onClick={(e) => {
                          e.stopPropagation();
                          handleNext();
                        }}
                        className="absolute right-4 top-1/2 transform -translate-y-1/2 bg-black/60 hover:bg-black/80 text-white rounded-full p-3 transition-all duration-200 hover:scale-110"
                        aria-label="Next image"
                      >
                        <ChevronRight size={24} />
                      </button>
                    </>
                  )}
                  
                  {/* Image counter */}
                  <div className="absolute bottom-4 left-1/2 transform -translate-x-1/2 bg-black/60 text-white px-3 py-1 rounded-full text-sm">
                    {currentImageIndex + 1} / {images.length}
                  </div>
                </div>
              </motion.div>
            ) : (
              // Masonry grid view
              <motion.div
                key="masonry-view"
                initial={{ scale: 0.95, opacity: 0 }}
                animate={{ scale: 1, opacity: 1 }}
                transition={{ duration: 0.3, delay: 0.1 }}
                className="max-w-7xl mx-auto"
              >
                <div className="grid grid-cols-1 md:grid-cols-2 lg:grid-cols-3 gap-4">
                  {imageColumns.map((column, colIdx) => (
                    <div key={colIdx} className="flex flex-col gap-4">
                      {column.map((img, imgIdx) => {
                        const imageIndex = images.findIndex(i => i.id === img.id);
                        return (
                          <motion.div
                            key={img.id}
                            initial={{ opacity: 0, y: 20 }}
                            animate={{ opacity: 1, y: 0 }}
                            transition={{ 
                              duration: 0.3, 
                              delay: 0.05 * (colIdx * 3 + imgIdx) 
                            }}
                            className="relative group cursor-pointer"
                            onClick={() => {
                              setCurrentImageIndex(imageIndex);
                              setViewMode('single');
                            }}
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
                        );
                      })}
                    </div>
                  ))}
                </div>
              </motion.div>
            )}
          </div>

          {/* Bottom hint - minimal */}
          <div className="absolute bottom-6 left-1/2 transform -translate-x-1/2 z-[10001] text-center">
            <p className="text-white/40 text-xs font-mono">
              {viewMode === 'single' 
                ? 'Use arrow keys to navigate • Press G for grid view • ESC to close'
                : 'Click an image to view • Press G for single view • ESC to close'}
            </p>
          </div>
        </motion.div>
      )}
    </AnimatePresence>
  );
}