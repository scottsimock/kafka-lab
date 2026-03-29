// Client Component: Real-time Kafka message viewer
// Uses 'use client' for state, effects, and event handlers

"use client";

import { useEffect, useState, useCallback } from "react";

interface KafkaMessage {
  topic: string;
  partition: number;
  offset: number;
  key: string | null;
  value: string;
  timestamp: string;
}

interface MessageViewerProps {
  topicName: string;
}

export default function MessageViewer({ topicName }: MessageViewerProps) {
  const [messages, setMessages] = useState<KafkaMessage[]>([]);
  const [isLoading, setIsLoading] = useState(false);
  const [error, setError] = useState<string | null>(null);
  const [autoRefresh, setAutoRefresh] = useState(false);

  const fetchMessages = useCallback(async () => {
    setIsLoading(true);
    setError(null);

    try {
      const res = await fetch(`/api/topics/${topicName}/messages?limit=50`);
      if (!res.ok) throw new Error(`HTTP ${res.status}`);

      const data = await res.json();
      setMessages(data.messages);
    } catch (err) {
      setError(err instanceof Error ? err.message : "Failed to fetch messages");
    } finally {
      setIsLoading(false);
    }
  }, [topicName]);

  useEffect(() => {
    fetchMessages();
  }, [fetchMessages]);

  useEffect(() => {
    if (!autoRefresh) return;

    const interval = setInterval(fetchMessages, 3000);
    return () => clearInterval(interval);
  }, [autoRefresh, fetchMessages]);

  return (
    <div className="space-y-4">
      <div className="flex items-center justify-between">
        <h2 className="text-xl font-semibold">
          Messages: {topicName}
        </h2>
        <div className="flex gap-2">
          <button
            onClick={fetchMessages}
            disabled={isLoading}
            className="px-4 py-2 bg-blue-600 text-white rounded hover:bg-blue-700 disabled:opacity-50"
          >
            {isLoading ? "Loading..." : "Refresh"}
          </button>
          <label className="flex items-center gap-2 cursor-pointer">
            <input
              type="checkbox"
              checked={autoRefresh}
              onChange={(e) => setAutoRefresh(e.target.checked)}
              className="rounded"
            />
            Auto-refresh
          </label>
        </div>
      </div>

      {error && (
        <div className="p-4 bg-red-50 border border-red-200 rounded text-red-700">
          {error}
        </div>
      )}

      <div className="overflow-x-auto">
        <table className="w-full border-collapse">
          <thead>
            <tr className="bg-gray-100">
              <th className="p-3 text-left">Partition</th>
              <th className="p-3 text-left">Offset</th>
              <th className="p-3 text-left">Key</th>
              <th className="p-3 text-left">Value</th>
              <th className="p-3 text-left">Timestamp</th>
            </tr>
          </thead>
          <tbody>
            {messages.map((msg) => (
              <tr
                key={`${msg.partition}-${msg.offset}`}
                className="border-t hover:bg-gray-50"
              >
                <td className="p-3">{msg.partition}</td>
                <td className="p-3 font-mono text-sm">{msg.offset}</td>
                <td className="p-3 font-mono text-sm">{msg.key ?? "—"}</td>
                <td className="p-3 font-mono text-sm max-w-md truncate">
                  {msg.value}
                </td>
                <td className="p-3 text-sm text-gray-500">{msg.timestamp}</td>
              </tr>
            ))}
            {messages.length === 0 && !isLoading && (
              <tr>
                <td colSpan={5} className="p-8 text-center text-gray-500">
                  No messages found
                </td>
              </tr>
            )}
          </tbody>
        </table>
      </div>
    </div>
  );
}
