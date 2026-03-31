'use client';

import { useEffect } from 'react';
import Link from 'next/link';

export default function Error({
  error,
  reset,
}: {
  error: Error & { digest?: string };
  reset: () => void;
}) {
  useEffect(() => {
    console.error('Consumer group detail error:', error);
  }, [error]);

  return (
    <div>
      <div style={{ marginBottom: '1rem' }}>
        <Link href="/dashboard/consumer-groups" style={{ color: '#0070f3', textDecoration: 'none' }}>
          ← Back to Consumer Groups
        </Link>
      </div>
      
      <h1>Consumer Group Details</h1>
      <div style={{
        padding: '1rem',
        backgroundColor: '#fee',
        border: '1px solid #fcc',
        borderRadius: '4px',
        marginTop: '1rem',
      }}>
        <h2 style={{ marginTop: 0 }}>Error loading consumer group details</h2>
        <p>{error.message}</p>
        <button
          onClick={() => reset()}
          style={{
            padding: '0.5rem 1rem',
            backgroundColor: '#0070f3',
            color: 'white',
            border: 'none',
            borderRadius: '4px',
            cursor: 'pointer',
          }}
        >
          Try again
        </button>
      </div>
    </div>
  );
}
