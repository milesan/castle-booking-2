import React, { useEffect, useState, useCallback } from 'react';
import { motion, AnimatePresence } from 'framer-motion';
import { X, ChevronLeft, ChevronRight, Grid3x3, Eye } from 'lucide-react';

interface GalleryImage {
  id: string;
  url: string;
  alt?: string;
}

interface SimpleImageGalleryProps {
  images: GalleryImage[];
  isOpen: boolean;
  onClose: () => void;
  title: string;
  startIndex?: number;
}

export function SimpleImageGallery({ 
  images, 
  isOpen, 
  onClose, 
  title, 
  startIndex = 0 
}: SimpleImageGalleryProps) {
  const [currentIndex, setCurrentIndex] = useState(startIndex);
  const [viewMode, setViewMode] = useState<'single' | 'grid'>('single');

  // Reset to start index when opened
  useEffect(() => {
    if (isOpen) {
      setCurrentIndex(Math.max(0, Math.min(startIndex, images.length - 1)));
      setViewMode('single');
    }
  }, [isOpen, startIndex, images.length]);

  // Navigation functions
  const goToPrevious = useCallback(() => {
    setCurrentIndex(prev => prev === 0 ? images.length - 1 : prev - 1);
  }, [images.length]);

  const goToNext = useCallback(() => {
    setCurrentIndex(prev => (prev + 1) % images.length);
  }, [images.length]);

  const goToImage = useCallback((index: number) => {
    setCurrentIndex(Math.max(0, Math.min(index, images.length - 1)));
    setViewMode('single');
  }, [images.length]);

  // Keyboard event handler
  useEffect(() => {
    if (!isOpen) return;

    const handleKeyDown = (e: KeyboardEvent) => {
      e.preventDefault();
      
      switch (e.key) {
        case 'Escape':
          onClose();
          break;
        case 'ArrowLeft':
          goToPrevious();
          break;
        case 'ArrowRight':
          goToNext();
          break;
        case 'g':
        case 'G':
          setViewMode(prev => prev === 'single' ? 'grid' : 'single');
          break;
      }
    };

    document.addEventListener('keydown', handleKeyDown);
    document.body.style.overflow = 'hidden';

    return () => {
      document.removeEventListener('keydown', handleKeyDown);
      document.body.style.overflow = '';
    };
  }, [isOpen, onClose, goToPrevious, goToNext]);

  if (!isOpen || images.length === 0) {
    return null;
  }

  return (
    <AnimatePresence>
      <motion.div
        initial={{ opacity: 0 }}
        animate={{ opacity: 1 }}
        exit={{ opacity: 0 }}
        className="fixed inset-0 z-[9999] bg-black/95 backdrop-blur-sm"
        onClick={(e) => {
          if (e.target === e.currentTarget) {
            onClose();
          }
        }}
      >
        {/* Header */}
        <div className="absolute top-0 left-0 right-0 z-10 flex items-center justify-between p-6">
          <div className="text-white">
            <h2 className="text-xl font-semibold">{title}</h2>
            <p className="text-sm text-white/60 mt-1">
              {currentIndex + 1} of {images.length}
            </p>
          </div>
          
          <div className="flex items-center gap-4">
            <button
              onClick={() => setViewMode(prev => prev === 'single' ? 'grid' : 'single')}
              className="text-white/60 hover:text-white p-2 rounded-lg hover:bg-white/10 transition-colors"
              title={`Switch to ${viewMode === 'single' ? 'grid' : 'single'} view (G)`}
            >
              {viewMode === 'single' ? <Grid3x3 size={20} /> : <Eye size={20} />}
            </button>
            
            <button
              onClick={onClose}
              className="text-white/60 hover:text-white p-2 rounded-lg hover:bg-white/10 transition-colors"
              title="Close (Esc)"
            >
              <X size={24} />
            </button>
          </div>
        </div>

        {/* Content */}
        <div className="absolute inset-0 pt-20">
          {viewMode === 'single' ? (
            // Single image view
            <div className="h-full flex items-center justify-center p-6">
              <div className="relative max-w-full max-h-full">
                <motion.img
                  key={currentIndex}
                  initial={{ opacity: 0, scale: 0.95 }}
                  animate={{ opacity: 1, scale: 1 }}
                  transition={{ duration: 0.2 }}
                  src={images[currentIndex].url}
                  alt={images[currentIndex].alt || `Image ${currentIndex + 1}`}
                  className="max-w-[90vw] max-h-[80vh] object-contain rounded-lg shadow-2xl"
                />
                
                {/* Navigation arrows */}
                {images.length > 1 && (
                  <>
                    <button
                      onClick={goToPrevious}
                      className="absolute left-4 top-1/2 -translate-y-1/2 bg-black/60 hover:bg-black/80 text-white rounded-full p-3 transition-all hover:scale-110"
                      title="Previous (←)"
                    >
                      <ChevronLeft size={24} />
                    </button>
                    
                    <button
                      onClick={goToNext}
                      className="absolute right-4 top-1/2 -translate-y-1/2 bg-black/60 hover:bg-black/80 text-white rounded-full p-3 transition-all hover:scale-110"
                      title="Next (→)"
                    >
                      <ChevronRight size={24} />
                    </button>
                  </>
                )}
              </div>
            </div>
          ) : (
            // Grid view
            <div className="h-full overflow-y-auto p-6">
              <div className="max-w-6xl mx-auto">
                <div className="grid grid-cols-2 md:grid-cols-3 lg:grid-cols-4 gap-4">
                  {images.map((image, index) => (
                    <motion.div
                      key={image.id}
                      initial={{ opacity: 0, y: 20 }}
                      animate={{ opacity: 1, y: 0 }}
                      transition={{ duration: 0.3, delay: index * 0.05 }}
                      className={`relative cursor-pointer rounded-lg overflow-hidden aspect-square bg-gray-800 ${
                        index === currentIndex ? 'ring-2 ring-white' : ''
                      }`}
                      onClick={() => goToImage(index)}
                    >
                      <img
                        src={image.url}
                        alt={image.alt || `Image ${index + 1}`}
                        className="w-full h-full object-cover hover:scale-105 transition-transform duration-200"
                      />
                      <div className="absolute inset-0 bg-black/0 hover:bg-black/20 transition-colors" />
                      {index === currentIndex && (
                        <div className="absolute inset-0 bg-white/10" />
                      )}
                    </motion.div>
                  ))}
                </div>
              </div>
            </div>
          )}
        </div>
      </motion.div>
    </AnimatePresence>
  );
}