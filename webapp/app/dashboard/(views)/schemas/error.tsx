'use client';

export default function Error({
  error,
  reset,
}: {
  error: Error & { digest?: string };
  reset: () => void;
}) {
  return (
    <div className="p-6">
      <h1 className="text-2xl font-bold mb-4">Schema Browser</h1>
      <div className="bg-red-50 border border-red-200 rounded-lg p-4">
        <p className="text-red-800 mb-2">Failed to load schemas</p>
        <p className="text-red-600 text-sm mb-4">{error.message}</p>
        <button
          onClick={reset}
          className="px-4 py-2 bg-red-600 text-white rounded hover:bg-red-700"
        >
          Try again
        </button>
      </div>
    </div>
  );
}
