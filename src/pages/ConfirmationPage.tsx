import React from 'react';
import { motion } from 'framer-motion';
import { CheckCircle, Calendar, MapPin, ArrowLeft } from 'lucide-react';
import { formatInTimeZone } from 'date-fns-tz';
import { Link, useLocation, useNavigate } from 'react-router-dom';
import { Fireflies, FireflyPresets } from '../components/Fireflies';
import { FireflyPortal } from '../components/FireflyPortal';

export function ConfirmationPage() {
  const location = useLocation();
  const navigate = useNavigate();
  const booking = location.state?.booking;

  console.log('[ConfirmationPage] Component rendered with:', {
    pathname: location.pathname,
    hasBooking: !!booking,
    bookingData: booking,
    locationState: location.state
  });

  React.useEffect(() => {
    console.log('[ConfirmationPage] useEffect - checking booking data:', { hasBooking: !!booking });
    // If user tries to access confirmation page directly without booking data
    if (!booking) {
      console.log('[ConfirmationPage] No booking data found, redirecting to /my-bookings');
      navigate('/my-bookings');
    }
  }, [booking, navigate]);

  // Handle back navigation
  React.useEffect(() => {
    const handleNavigation = (e: PopStateEvent) => {
      console.log('[ConfirmationPage] popstate event fired:', {
        hasBooking: !!booking,
        currentPath: window.location.pathname,
        event: e
      });
      // Only redirect if there's no booking data (user accessed page directly)
      if (!booking) {
        console.log('[ConfirmationPage] No booking data on popstate, redirecting to /my-bookings');
        navigate('/my-bookings');
      } else {
        console.log('[ConfirmationPage] Booking data exists on popstate, allowing navigation');
      }
    };

    console.log('[ConfirmationPage] Adding popstate event listener');
    window.addEventListener('popstate', handleNavigation);
    return () => {
      console.log('[ConfirmationPage] Removing popstate event listener');
      window.removeEventListener('popstate', handleNavigation);
    };
  }, [booking, navigate]);

  // Add a general navigation listener to see all navigation attempts
  React.useEffect(() => {
    const handleBeforeUnload = () => {
      console.log('[ConfirmationPage] beforeunload event fired');
    };

    const handleNavigationStart = () => {
      console.log('[ConfirmationPage] Navigation starting to:', window.location.pathname);
    };

    console.log('[ConfirmationPage] Adding navigation event listeners');
    window.addEventListener('beforeunload', handleBeforeUnload);
    window.addEventListener('popstate', handleNavigationStart);
    
    return () => {
      console.log('[ConfirmationPage] Removing navigation event listeners');
      window.removeEventListener('beforeunload', handleBeforeUnload);
      window.removeEventListener('popstate', handleNavigationStart);
    };
  }, []);

  if (!booking) {
    console.log('[ConfirmationPage] No booking data, returning null');
    return null;
  }

  return (
    <div className="flex items-center justify-center p-4">
      <FireflyPortal />
      {/* Add subtle fireflies in the background */}
      <Fireflies 
        {...FireflyPresets.subtle}
        count={20}
        className="opacity-60"
      />
      
      <motion.div 
        initial={{ opacity: 0, y: 20 }}
        animate={{ opacity: 1, y: 0 }}
        className="max-w-2xl w-full rounded-sm shadow-sm border border-border overflow-hidden bg-[var(--color-bg-surface)]"
      >
        <div className="p-8 text-center border-b border-border">
          <motion.div
            initial={{ scale: 0 }}
            animate={{ scale: 1 }}
            transition={{ delay: 0.2, type: "spring", stiffness: 200 }}
            className="w-16 h-16 bg-emerald-900/20 rounded-full flex items-center justify-center mx-auto mb-6"
          >
            <CheckCircle className="w-8 h-8 text-emerald-400" />
          </motion.div>
          
          <h1 className="text-3xl font-display font-light text-text-primary mb-2">
            Booking Confirmed
          </h1>
          <p className="text-text-secondary font-mono">
            The Castle awaits
          </p>
          <p className="text-text-secondary/80 font-mono text-sm mt-2">
            A confirmation email has been sent to your registered email address
          </p>
        </div>

        <div className="p-8 space-y-6">
          {/* Show manual creation message if present */}
          {booking.isPendingManualCreation && booking.manualCreationMessage && (
            <div className="bg-amber-900/20 p-4 rounded-sm border border-amber-900/30 mb-6">
              <p className="text-amber-300 font-mono text-sm">
                {booking.manualCreationMessage}
              </p>
            </div>
          )}

          <div className="grid grid-cols-1 md:grid-cols-2 gap-6">
            <div className="space-y-2">
              <div className="flex items-center gap-2 text-text-secondary">
                <Calendar className="w-4 h-4" />
                <span className="text-sm font-mono">Check-in</span>
              </div>
              <p className="font-mono text-xl text-text-primary">
                {formatInTimeZone(new Date(booking.checkIn), 'UTC', 'EEEE, MMMM d')}
              </p>
            </div>

            <div className="space-y-2">
              <div className="flex items-center gap-2 text-text-secondary">
                <Calendar className="w-4 h-4" />
                <span className="text-sm font-mono">Check-out</span>
              </div>
              <p className="font-mono text-xl text-text-primary">
                {formatInTimeZone(new Date(booking.checkOut), 'UTC', 'EEEE, MMMM d')}
              </p>
            </div>

            <div className="space-y-2">
              <div className="flex items-center gap-2 text-text-secondary">
                <MapPin className="w-4 h-4" />
                <span className="text-sm font-mono">Accommodation</span>
              </div>
              <p className="font-mono text-xl text-text-primary">
                {booking.accommodation}
              </p>
            </div>

          </div>


          <div className="border-t border-border pt-6">
            <div className="flex justify-between items-center text-lg font-mono text-text-primary">
              <span>Total Amount Donated</span>
              <span>€{booking.totalPrice}</span>
            </div>
          </div>


          <Link 
            to="/my-bookings"
            className="inline-flex items-center gap-2 text-text-secondary hover:text-text-primary transition-colors"
          >
            <ArrowLeft className="w-4 h-4" />
            <span className="font-mono text-sm">View All Bookings</span>
          </Link>
        </div>
      </motion.div>
    </div>
  );
}
