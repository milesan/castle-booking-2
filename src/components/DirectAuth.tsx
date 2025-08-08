import React, { useState, useEffect } from 'react';
import { supabase } from '../lib/supabase';
import { Book2Page } from '../pages/Book2Page';

export function DirectAuth() {
  const [authState, setAuthState] = useState<'checking' | 'authenticated' | 'needs_otp' | 'denied'>('checking');
  const [email, setEmail] = useState('');
  const [otp, setOtp] = useState('');
  const [error, setError] = useState<string | null>(null);
  const [isLoading, setIsLoading] = useState(false);

  useEffect(() => {
    checkAuthStatus();
  }, []);

  const checkAuthStatus = async () => {
    try {
      const { data: { session } } = await supabase.auth.getSession();
      
      if (session) {
        // User is already authenticated, check if they're in whitelist
        const { data: whitelistData } = await supabase
          .from('whitelist_all')
          .select('email, status')
          .eq('email', session.user.email)
          .single();

        if (whitelistData) {
          setAuthState('authenticated');
        } else {
          setAuthState('denied');
        }
      } else {
        setAuthState('needs_otp');
      }
    } catch (err) {
      console.error('Auth check error:', err);
      setAuthState('needs_otp');
    }
  };

  const handleSendOtp = async (e: React.FormEvent) => {
    e.preventDefault();
    setError(null);
    setIsLoading(true);

    try {
      const normalizedEmail = email.toLowerCase().trim();

      // Check if user is in whitelist
      const { data: whitelistData, error: whitelistError } = await supabase
        .from('whitelist_all')
        .select('email, status')
        .eq('email', normalizedEmail)
        .single();

      if (whitelistError || !whitelistData) {
        throw new Error('Access denied. Contact an administrator to be added to the whitelist.');
      }

      // Send OTP
      const { error } = await supabase.auth.signInWithOtp({ 
        email: normalizedEmail,
        options: {
          emailRedirectTo: undefined
        }
      });
      
      if (error) throw error;
      
      setAuthState('needs_otp');
    } catch (err: any) {
      setError(err.message);
    } finally {
      setIsLoading(false);
    }
  };

  const handleVerifyOtp = async (e: React.FormEvent) => {
    e.preventDefault();
    setError(null);
    setIsLoading(true);

    try {
      const { data, error } = await supabase.auth.verifyOtp({
        email: email.toLowerCase().trim(),
        token: otp,
        type: 'email',
      });

      if (error) throw error;
      
      if (data.session) {
        setAuthState('authenticated');
      } else {
        throw new Error('Verification failed');
      }
    } catch (err: any) {
      setError(err.message);
    } finally {
      setIsLoading(false);
    }
  };

  // Show Book2Page if authenticated
  if (authState === 'authenticated') {
    return <Book2Page />;
  }

  // Show loading state
  if (authState === 'checking') {
    return (
      <div className="min-h-screen flex items-center justify-center">
        <div className="animate-spin rounded-full h-8 w-8 border-b-2 border-emerald-500"></div>
      </div>
    );
  }

  // Show access denied
  if (authState === 'denied') {
    return (
      <div className="min-h-screen flex items-center justify-center p-4">
        <div className="max-w-md w-full text-center">
          <h1 className="text-2xl font-bold text-red-600 mb-4">Access Denied</h1>
          <p className="text-gray-600">
            You're not authorized to access this system. Contact an administrator to be added to the whitelist.
          </p>
        </div>
      </div>
    );
  }

  // Show OTP form
  return (
    <div className="min-h-screen flex items-center justify-center p-4">
      <div className="max-w-md w-full">
        <div className="bg-white rounded-lg shadow-md p-6">
          <h1 className="text-2xl font-bold text-center mb-6">Castle Booking Access</h1>
          
          {error && (
            <div className="mb-4 p-3 bg-red-50 border border-red-200 rounded text-red-800">
              {error}
            </div>
          )}

          {!otp ? (
            <form onSubmit={handleSendOtp} className="space-y-4">
              <div>
                <label htmlFor="email" className="block text-sm font-medium text-gray-700 mb-1">
                  Email
                </label>
                <input
                  type="email"
                  id="email"
                  value={email}
                  onChange={(e) => setEmail(e.target.value)}
                  className="w-full px-3 py-2 border border-gray-300 rounded-md focus:outline-none focus:ring-2 focus:ring-emerald-500"
                  required
                  disabled={isLoading}
                />
              </div>
              
              <button
                type="submit"
                disabled={isLoading}
                className="w-full bg-emerald-600 text-white py-2 px-4 rounded-md hover:bg-emerald-700 disabled:opacity-50 disabled:cursor-not-allowed"
              >
                {isLoading ? 'Sending...' : 'Send Code'}
              </button>
            </form>
          ) : (
            <form onSubmit={handleVerifyOtp} className="space-y-4">
              <div>
                <label htmlFor="otp" className="block text-sm font-medium text-gray-700 mb-1">
                  Enter verification code
                </label>
                <input
                  type="text"
                  id="otp"
                  value={otp}
                  onChange={(e) => setOtp(e.target.value)}
                  className="w-full px-3 py-2 border border-gray-300 rounded-md focus:outline-none focus:ring-2 focus:ring-emerald-500"
                  required
                  disabled={isLoading}
                />
              </div>
              
              <button
                type="submit"
                disabled={isLoading}
                className="w-full bg-emerald-600 text-white py-2 px-4 rounded-md hover:bg-emerald-700 disabled:opacity-50 disabled:cursor-not-allowed"
              >
                {isLoading ? 'Verifying...' : 'Verify Code'}
              </button>
              
              <button
                type="button"
                onClick={() => setOtp('')}
                className="w-full text-sm text-gray-500 hover:text-gray-700"
              >
                ← Back to email
              </button>
            </form>
          )}
        </div>
      </div>
    </div>
  );
}