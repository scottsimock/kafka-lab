'use client';

import { useEffect } from 'react';

export default function MessagesError({
  error,
  reset,
}: {
  error: Error & { digest?: string };
  reset: () => void;
}) {
  useEffect(() => {
    console.error('Messages page error:', error);
  }, [error]);

  return (
    <div className="p-6">
      <div className="border border-red-300 bg-red-50 rounded-lg p-6 max-w-2xl mx-auto mt-8">
        <h2 className="text-xl font-semibold text-red-800 mb-4">
          Failed to Load Message Browser
        </h2>
        <p className="text-red-700 mb-4">
          {error.message || 'An unexpected error occurred while loading the message browser.'}
        </p>
        {error.digest && (
          <p className="text-sm text-red-600 mb-4">
            Error ID: {error.digest}
          </p>
        )}
        <button
          onClick={reset}
          className="px-4 py-2 bg-red-600 text-white rounded-md hover:bg-red-700"
        >
          Try Again
        </button>
      </div>
    </div>
  );
}
