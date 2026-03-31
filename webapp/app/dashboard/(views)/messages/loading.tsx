export default function MessagesLoading() {
  return (
    <div className="p-6">
      <div className="animate-pulse space-y-6">
        <div className="h-8 bg-gray-200 rounded w-48"></div>
        <div className="h-12 bg-gray-200 rounded w-96"></div>
        <div className="h-64 bg-gray-200 rounded"></div>
        <div className="h-96 bg-gray-200 rounded"></div>
      </div>
      <p className="text-center text-gray-500 mt-4">Loading message browser...</p>
    </div>
  );
}
