import React, { useState, useCallback } from 'react';
import { ChevronLeft, ChevronRight } from 'lucide-react';

interface ThumbnailImage {
  id: string;
  url: string;
  alt?: string;
}

interface SimpleThumbnailGalleryProps {
  images: ThumbnailImage[];
  onImageClick: (index: number) => void;
  className?: string;
}

export function SimpleThumbnailGallery({ 
  images, 
  onImageClick, 
  className = '' 
}: SimpleThumbnailGalleryProps) {
  const [currentIndex, setCurrentIndex] = useState(0);

  const goToPrevious = useCallback((e: React.MouseEvent) => {
    e.stopPropagation();
    setCurrentIndex(prev => prev === 0 ? images.length - 1 : prev - 1);
  }, [images.length]);

  const goToNext = useCallback((e: React.MouseEvent) => {
    e.stopPropagation();
    setCurrentIndex(prev => (prev + 1) % images.length);
  }, [images.length]);

  const handleImageClick = useCallback((e: React.MouseEvent) => {
    e.stopPropagation();
    onImageClick(currentIndex);
  }, [currentIndex, onImageClick]);

  const handleDotClick = useCallback((e: React.MouseEvent, index: number) => {
    e.stopPropagation();
    setCurrentIndex(index);
  }, []);

  if (images.length === 0) {
    return (
      <div className={`relative bg-gray-200 flex items-center justify-center ${className}`}>
        <span className="text-gray-400 text-sm">No image</span>
      </div>
    );
  }

  const currentImage = images[currentIndex];

  return (
    <div 
      className={`relative group cursor-pointer ${className}`}
      onClick={handleImageClick}
    >
      {/* Main Image */}
      <img
        src={currentImage.url}
        alt={currentImage.alt || `Image ${currentIndex + 1}`}
        className="w-full h-full object-cover transition-transform duration-200 group-hover:scale-105"
      />
      
      {/* Navigation Overlay */}
      <div className="absolute inset-0 bg-gradient-to-t from-black/20 to-transparent opacity-0 group-hover:opacity-100 transition-opacity duration-200" />
      
      {/* Navigation Arrows */}
      {images.length > 1 && (
        <>
          <button
            onClick={goToPrevious}
            className="absolute left-2 top-1/2 -translate-y-1/2 bg-black/60 hover:bg-black/80 text-white rounded-full p-2 opacity-0 group-hover:opacity-100 transition-all duration-200 hover:scale-110 z-20"
            title="Previous image"
          >
            <ChevronLeft size={16} />
          </button>
          
          <button
            onClick={goToNext}
            className="absolute right-2 top-1/2 -translate-y-1/2 bg-black/60 hover:bg-black/80 text-white rounded-full p-2 opacity-0 group-hover:opacity-100 transition-all duration-200 hover:scale-110 z-20"
            title="Next image"
          >
            <ChevronRight size={16} />
          </button>
        </>
      )}

      {/* Dots Indicator */}
      {images.length > 1 && (
        <div className="absolute bottom-2 left-1/2 -translate-x-1/2 flex space-x-1 opacity-0 group-hover:opacity-100 transition-opacity duration-200 z-10">
          {images.map((_, index) => (
            <button
              key={index}
              onClick={(e) => handleDotClick(e, index)}
              className={`w-2 h-2 rounded-full transition-all duration-200 border border-white/50 ${
                index === currentIndex 
                  ? 'bg-white' 
                  : 'bg-white/30 hover:bg-white/60'
              }`}
              title={`Go to image ${index + 1}`}
            />
          ))}
        </div>
      )}
    </div>
  );
}