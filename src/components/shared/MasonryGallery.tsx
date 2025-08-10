import React, { useEffect, useState, useRef, useCallback } from 'react';
import { motion, AnimatePresence } from 'framer-motion';
import { X } from 'lucide-react';
import clsx from 'clsx';

interface MasonryGalleryProps {
  images: Array<{
    id: string;
    image_url: string;
    display_order: number;
  }>;
  isOpen: boolean;
  onClose: () => void;
  title?: string;
}

export function MasonryGallery({ images, isOpen, onClose, title }: MasonryGalleryProps) {
  console.log('🎨 MasonryGallery component called with:', {
    isOpen,
    imagesCount: images.length,
    title,
    images: images.slice(0, 2) // Show first 2 images for debugging
  });
  
  const [columns, setColumns] = useState(3);
  const [imagesLoaded, setImagesLoaded] = useState<Set<string>>(new Set());
  const galleryRef = useRef<HTMLDivElement>(null);

  // Sort images by display order
  const sortedImages = [...images].sort((a, b) => a.display_order - b.display_order);

  // Calculate responsive columns based on window size
  useEffect(() => {
    const calculateColumns = () => {
      const width = window.innerWidth;
      if (width < 640) setColumns(1);
      else if (width < 1024) setColumns(2);
      else if (width < 1536) setColumns(3);
      else setColumns(4);
    };

    calculateColumns();
    window.addEventListener('resize', calculateColumns);
    return () => window.removeEventListener('resize', calculateColumns);
  }, []);

  // Close on escape key
  useEffect(() => {
    const handleEscape = (e: KeyboardEvent) => {
      if (e.key === 'Escape' && isOpen) {
        onClose();
      }
    };

    if (isOpen) {
      document.addEventListener('keydown', handleEscape);
      document.body.style.overflow = 'hidden';
    }

    return () => {
      document.removeEventListener('keydown', handleEscape);
      document.body.style.overflow = 'unset';
    };
  }, [isOpen, onClose]);

  const handleImageLoad = useCallback((imageId: string) => {
    setImagesLoaded(prev => new Set(prev).add(imageId));
  }, []);

  // Distribute images across columns
  const distributeImages = () => {
    const cols: typeof sortedImages[] = Array.from({ length: columns }, () => []);
    const colHeights = new Array(columns).fill(0);

    sortedImages.forEach((image, index) => {
      // For a more balanced distribution, alternate columns in first pass
      if (index < columns) {
        cols[index].push(image);
        colHeights[index]++;
      } else {
        // Then fill shortest column
        const shortestCol = colHeights.indexOf(Math.min(...colHeights));
        cols[shortestCol].push(image);
        colHeights[shortestCol]++;
      }
    });

    return cols;
  };

  const imageColumns = distributeImages();

  return (
    <AnimatePresence>
      {isOpen && (
        <motion.div
          initial={{ opacity: 0 }}
          animate={{ opacity: 1 }}
          exit={{ opacity: 0 }}
          transition={{ duration: 0.3, ease: 'easeInOut' }}
          className="fixed inset-0 z-[100] bg-[var(--castle-bg-overlay)] backdrop-blur-2xl"
          onClick={onClose}
        >
          {/* Header */}
          <motion.div
            initial={{ y: -20, opacity: 0 }}
            animate={{ y: 0, opacity: 1 }}
            transition={{ delay: 0.1, duration: 0.3 }}
            className="absolute top-0 left-0 right-0 z-[110] bg-gradient-to-b from-[var(--castle-bg-primary)] via-[var(--castle-bg-primary)]/80 to-transparent pb-8 pt-6 px-6"
          >
            <div className="max-w-[1800px] mx-auto flex items-center justify-between">
              {title && (
                <h2 className="font-mono text-[var(--castle-text-primary)] text-sm uppercase tracking-wider">
                  {title}
                </h2>
              )}
              <button
                onClick={onClose}
                className="ml-auto group relative"
                aria-label="Close gallery"
              >
                <div className="absolute inset-0 bg-[var(--castle-accent-gold)]/10 rounded-full scale-0 group-hover:scale-150 transition-transform duration-300" />
                <div className="relative bg-[var(--castle-bg-surface)] border border-[var(--castle-border-primary)] rounded-full p-2 group-hover:border-[var(--castle-accent-gold)] transition-colors duration-200">
                  <X className="w-4 h-4 text-[var(--castle-text-secondary)] group-hover:text-[var(--castle-accent-gold)]" />
                </div>
              </button>
            </div>
          </motion.div>

          {/* Masonry Grid */}
          <div
            ref={galleryRef}
            className="h-full overflow-y-auto overflow-x-hidden pt-20 pb-6 px-6"
            onClick={(e) => e.stopPropagation()}
          >
            <motion.div
              initial={{ opacity: 0, y: 20 }}
              animate={{ opacity: 1, y: 0 }}
              transition={{ delay: 0.2, duration: 0.4 }}
              className="max-w-[1800px] mx-auto"
            >
              <div className={clsx(
                "grid gap-4",
                columns === 1 && "grid-cols-1",
                columns === 2 && "grid-cols-2",
                columns === 3 && "grid-cols-3",
                columns === 4 && "grid-cols-4"
              )}>
                {imageColumns.map((column, colIndex) => (
                  <div key={colIndex} className="flex flex-col gap-4">
                    {column.map((image, imageIndex) => (
                      <motion.div
                        key={image.id}
                        initial={{ opacity: 0, scale: 0.95 }}
                        animate={{ 
                          opacity: imagesLoaded.has(image.id) ? 1 : 0,
                          scale: imagesLoaded.has(image.id) ? 1 : 0.95
                        }}
                        transition={{ 
                          delay: (colIndex * 0.05) + (imageIndex * 0.03),
                          duration: 0.4,
                          ease: 'easeOut'
                        }}
                        className="relative group cursor-pointer"
                        onClick={onClose}
                      >
                        {/* Image container with aspect ratio preservation */}
                        <div className="relative overflow-hidden rounded-sm bg-[var(--castle-bg-surface)] border border-[var(--castle-border-primary)]/30">
                          {/* Loading skeleton */}
                          {!imagesLoaded.has(image.id) && (
                            <div className="absolute inset-0 bg-[var(--castle-bg-surface)] animate-pulse">
                              <div className="w-full h-full bg-gradient-to-br from-[var(--castle-border-primary)]/10 to-transparent" />
                            </div>
                          )}
                          
                          {/* Actual image */}
                          <img
                            src={image.image_url}
                            alt={`Gallery image ${image.display_order + 1}`}
                            className={clsx(
                              "w-full h-auto block transition-all duration-500",
                              "group-hover:scale-105",
                              imagesLoaded.has(image.id) ? "opacity-100" : "opacity-0"
                            )}
                            loading="lazy"
                            onLoad={() => handleImageLoad(image.id)}
                          />

                          {/* Subtle overlay on hover */}
                          <div className="absolute inset-0 bg-gradient-to-t from-[var(--castle-bg-primary)]/20 to-transparent opacity-0 group-hover:opacity-100 transition-opacity duration-300 pointer-events-none" />
                        </div>

                        {/* Subtle glow effect on hover */}
                        <div className="absolute -inset-1 bg-[var(--castle-accent-gold)]/5 rounded-sm opacity-0 group-hover:opacity-100 blur-xl transition-opacity duration-500 pointer-events-none" />
                      </motion.div>
                    ))}
                  </div>
                ))}
              </div>
            </motion.div>
          </div>

          {/* Subtle gradient at bottom for scroll indication */}
          <div className="absolute bottom-0 left-0 right-0 h-20 bg-gradient-to-t from-[var(--castle-bg-primary)]/50 to-transparent pointer-events-none" />
        </motion.div>
      )}
    </AnimatePresence>
  );
}