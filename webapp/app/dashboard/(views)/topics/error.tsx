'use client';

export default function TopicsError({
  error,
  reset,
}: {
  error: Error & { digest?: string };
  reset: () => void;
}) {
  return (
    <div>
      <h1>Topics</h1>
      <div style={{ marginTop: '1rem', padding: '1rem', backgroundColor: '#fee', border: '1px solid #fcc' }}>
        <h2 style={{ marginTop: 0 }}>Error loading topics</h2>
        <p>{error.message}</p>
        <button onClick={reset} style={{ marginTop: '1rem', padding: '0.5rem 1rem', cursor: 'pointer' }}>
          Retry
        </button>
      </div>
    </div>
  );
}
