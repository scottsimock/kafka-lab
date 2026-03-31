'use client';

import { useRouter } from 'next/navigation';
import { useTransition } from 'react';

export function RefreshButton() {
  const router = useRouter();
  const [isPending, startTransition] = useTransition();
  
  return (
    <button
      onClick={() => startTransition(() => router.refresh())}
      disabled={isPending}
      style={{
        padding: '0.5rem 1rem',
        backgroundColor: isPending ? '#ccc' : '#0070f3',
        color: 'white',
        border: 'none',
        borderRadius: '4px',
        cursor: isPending ? 'not-allowed' : 'pointer',
      }}
    >
      {isPending ? 'Refreshing…' : '↻ Refresh'}
    </button>
  );
}
