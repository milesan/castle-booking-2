import { useState, useEffect, useCallback } from "react";
import { loadStripe, Stripe } from '@stripe/stripe-js';
import { EmbeddedCheckoutProvider, EmbeddedCheckout } from '@stripe/react-stripe-js';
import { createPortal } from 'react-dom';

// Lazy-load Stripe and check for public key at runtime
let stripePromise: Promise<Stripe | null> | null = null;
function getStripePromise() {
  const key = import.meta.env.VITE_STRIPE_PUBLIC_KEY;
  if (!key || typeof key !== 'string') {
    throw new Error('Missing or invalid Stripe public key!');
  }
  if (!stripePromise) {
    stripePromise = loadStripe(key);
  }
  return stripePromise;
}

interface Props {
  description: string;
  total: number;
  authToken: string;
  userEmail: string;
  onSuccess: (paymentIntentId?: string, paymentRowId?: string) => Promise<void>;
  onClose: () => void;
  // Add booking metadata for enhanced error recovery
  bookingMetadata?: {
    accommodationId?: string;
    checkIn?: string;
    checkOut?: string;
    originalTotal?: number;
    creditsUsed?: number;
    discountCode?: string;
  };
  // Add paymentRowId to pass to success handler
  paymentRowId?: string;
}

export function StripeCheckoutForm({ total, authToken, description, userEmail, onSuccess, onClose, bookingMetadata, paymentRowId }: Props) {
  // Create dynamic mailto URL with room information
  const createCryptoMailtoUrl = () => {
    const subject = encodeURIComponent("Bitcoin/Ethereum Payment Request");
    const body = encodeURIComponent(`Hi,

I'd like to pay with cryptocurrency for my booking:

${description}
Total: €${total}

Please provide Bitcoin or Ethereum payment details.

Thank you!`);
    
    return `mailto:concierge@castle.community?subject=${subject}&body=${body}`;
  };
  useEffect(() => {
    console.log('[StripeCheckout] Current environment:', import.meta.env.MODE);
  }, []);
  const [clientSecret, setClientSecret] = useState<string | null>(null);

  // When component mounts, add a class to body to prevent scrolling and hide the header
  useEffect(() => {
    document.body.style.overflow = 'hidden';
    
    // Find and hide the header
    const header = document.querySelector('header');
    if (header) {
      console.log('[StripeCheckout] Found header, hiding it temporarily');
      header.style.display = 'none';
    } else {
      console.warn('[StripeCheckout] Could not find header element');
    }
    
    // Clean up when component unmounts
    return () => {
      document.body.style.overflow = '';
      
      // Restore the header
      const header = document.querySelector('header');
      if (header) {
        header.style.display = '';
      }
    };
  }, []);

  useEffect(() => {
    const fetchSecret = async () => {
      try {
        // Pass the current environment to the edge function
        const environment = import.meta.env.MODE;
        console.log('[StripeCheckout] Sending request with environment and email:', environment, userEmail);
        
        // Check if we're in development mode without Edge Functions
        const isDevelopment = import.meta.env.MODE === 'development';
        
        if (isDevelopment && !import.meta.env.VITE_STRIPE_SECRET_KEY) {
          // In development without Edge Functions, create a test client secret
          // This is just for testing - in production you need proper Edge Functions
          console.warn('[StripeCheckout] Edge Functions not available - using test mode');
          
          // For testing, we'll show a message
          alert('Stripe Edge Functions are not configured. In production, you need to deploy the Edge Functions for payment processing.');
          
          // Call onSuccess directly for testing (simulating successful payment)
          if (total === 0) {
            // Free booking - proceed directly
            await onSuccess(undefined, paymentRowId);
            return;
          }
          
          // For non-zero amounts, show error
          throw new Error('Stripe Edge Functions required for payment processing');
        }
        
        const response = await fetch(`${import.meta.env.VITE_SUPABASE_URL}/functions/v1/stripe-webhook`, {
          method: "POST",
          mode: 'cors',
          headers: {
            Authorization: `Bearer ${authToken}`,
            'Content-Type': 'application/json',
          },
          body: JSON.stringify({ 
            total, 
            description,
            environment,
            email: userEmail,
            bookingMetadata
          }),
        });
        
        if (!response.ok) {
          throw new Error(`Stripe webhook failed: ${response.status}`);
        }
        
        const data = await response.json();
        setClientSecret(data.clientSecret);
      } catch (error) {
        console.error('[StripeCheckout] Error fetching client secret:', error);
        // For free bookings, we can proceed without Stripe
        if (total === 0) {
          console.log('[StripeCheckout] Free booking detected, proceeding without payment');
          await onSuccess(undefined, paymentRowId);
          onClose();
        } else {
          alert('Unable to initialize payment system. Please ensure Stripe Edge Functions are deployed.');
          onClose();
        }
      }
    };
    fetchSecret();
  }, [authToken, total, description, userEmail, bookingMetadata, paymentRowId, onSuccess, onClose]);

  const handleCheckoutComplete = useCallback(async () => {
    console.log('[StripeCheckout] Payment completed, checking status...');
    
    // Also pass environment to the status endpoint
    const environment = import.meta.env.MODE;
    
    const response = await fetch(`${import.meta.env.VITE_SUPABASE_URL}/functions/v1/stripe-webhook-status`, {
      method: "POST",
      mode: 'cors',
      headers: {
        Authorization: `Bearer ${authToken}`,
        'Content-Type': 'application/json',
      },
      body: JSON.stringify({ 
        clientSecret,
        environment // Pass the environment to the status edge function
      }),
    });
    const { status, paymentIntentId } = await response.json();
    
    if (status === 'completed' || status === 'paid') {  // Check both values for compatibility
      console.log('[StripeCheckout] Payment confirmed, proceeding with booking...');
      console.log('[StripeCheckout] Payment Intent ID:', paymentIntentId);
      
      try {
        // Pass the payment intent ID to the success handler
        await onSuccess(paymentIntentId, paymentRowId);
        // If successful, the parent component will handle navigation
      } catch (error) {
        console.error('[StripeCheckout] Booking creation failed after payment:', error);
        // Close the modal so the parent component can show the error
        onClose();
      }
    } else {
      console.error('[StripeCheckout] Payment status not paid:', status);
      // Close modal on payment failure too
      onClose();
    }
  }, [authToken, clientSecret, onSuccess, onClose, paymentRowId]);

  if (!clientSecret) {
    return <div>Loading checkout...</div>;
  }

  console.log('[StripeCheckout] Rendering as portal outside normal component hierarchy');

  const checkoutContent = (
    <div 
      style={{ 
        position: 'fixed',
        top: '0',
        left: '0',
        width: '100%',
        height: '100%',
        backgroundColor: 'rgba(0, 0, 0, 0.75)',
        display: 'flex',
        justifyContent: 'center',
        alignItems: 'center',
        zIndex: 999999,
        isolation: 'isolate'
      }}
    >
      <div 
        id="checkout" 
        style={{ 
          position: 'relative',
          width: '100%', 
          maxWidth: '500px',
          maxHeight: '90vh', 
          overflow: 'auto',
          padding: '20px',
          margin: '0 auto',
          backgroundColor: '#fff',
          borderRadius: '8px',
          boxShadow: '0 4px 16px rgba(0, 0, 0, 0.2)',
          zIndex: 999999
        }}
      >
        {/* Close Button */}
        <button
          onClick={onClose}
          style={{
            position: 'absolute',
            top: '10px',
            right: '10px',
            border: 'none',
            fontSize: '24px',
            cursor: 'pointer',
            color: '#333',
            zIndex: 1000000,
            width: '32px',
            height: '32px',
            borderRadius: '50%',
            backgroundColor: 'rgba(200, 200, 200, 0.7)',
            display: 'flex',
            alignItems: 'center',
            justifyContent: 'center',
            lineHeight: '1'
          }}
          aria-label="Close payment form"
        >
          &times;
        </button>
        <div style={{ position: 'relative', zIndex: 999999 }}>
          <EmbeddedCheckoutProvider
            stripe={getStripePromise()}
            options={{
              clientSecret,
              onComplete: handleCheckoutComplete,
            }}
          >
            <EmbeddedCheckout />
          </EmbeddedCheckoutProvider>
          {/* Crypto payment option */}
          <div style={{ 
            marginTop: '16px', 
            paddingTop: '16px', 
            borderTop: '1px solid #e0e0e0',
            textAlign: 'center'
          }}>
            <a 
              href={createCryptoMailtoUrl()}
              style={{
                color: '#666',
                fontSize: '13px',
                textDecoration: 'none',
                transition: 'color 0.2s'
              }}
              onMouseEnter={(e) => e.currentTarget.style.color = '#000'}
              onMouseLeave={(e) => e.currentTarget.style.color = '#666'}
            >
              BTC &amp; ETH accepted →
            </a>
          </div>
        </div>
      </div>
    </div>
  );
  
  // Render our component at the document root, outside of any other stacking contexts
  return createPortal(checkoutContent, document.body);
}

// For backwards compatibility, export with the previous name too
export { StripeCheckoutForm as default };