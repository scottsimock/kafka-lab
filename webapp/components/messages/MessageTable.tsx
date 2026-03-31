'use client';

import { useState } from 'react';

interface Message {
  key: string | undefined;
  value: string | undefined;
  partition: number;
  offset: string;
  timestamp: string;
  headers?: Record<string, string>;
}

interface MessageTableProps {
  messages: Message[];
}

export function MessageTable({ messages }: MessageTableProps) {
  const [expandedRows, setExpandedRows] = useState<Set<string>>(new Set());

  const toggleRow = (id: string) => {
    setExpandedRows((prev) => {
      const next = new Set(prev);
      if (next.has(id)) {
        next.delete(id);
      } else {
        next.add(id);
      }
      return next;
    });
  };

  const truncateValue = (value: string | undefined, maxLength: number = 200) => {
    if (!value) return '';
    if (value.length <= maxLength) return value;
    return value.substring(0, maxLength) + '...';
  };

  const formatTimestamp = (timestamp: string) => {
    try {
      return new Date(parseInt(timestamp)).toLocaleString();
    } catch {
      return timestamp;
    }
  };

  if (messages.length === 0) {
    return (
      <div className="border border-gray-300 rounded-lg p-8 text-center text-gray-500">
        No messages to display. Select a topic and fetch or stream messages.
      </div>
    );
  }

  return (
    <div className="border border-gray-300 rounded-lg overflow-hidden">
      <h2 className="text-lg font-semibold p-4 bg-gray-50 border-b border-gray-300">
        Messages ({messages.length})
      </h2>
      
      <div className="overflow-x-auto">
        <table className="w-full">
          <thead className="bg-gray-100 border-b border-gray-300">
            <tr>
              <th className="px-4 py-3 text-left text-sm font-medium">Key</th>
              <th className="px-4 py-3 text-left text-sm font-medium">Value</th>
              <th className="px-4 py-3 text-left text-sm font-medium">Partition</th>
              <th className="px-4 py-3 text-left text-sm font-medium">Offset</th>
              <th className="px-4 py-3 text-left text-sm font-medium">Timestamp</th>
            </tr>
          </thead>
          <tbody>
            {messages.map((message, index) => {
              const rowId = `${message.partition}-${message.offset}`;
              const isExpanded = expandedRows.has(rowId);
              const valueDisplay = isExpanded
                ? message.value
                : truncateValue(message.value);

              return (
                <tr
                  key={`${rowId}-${index}`}
                  className="border-b border-gray-200 hover:bg-gray-50"
                >
                  <td className="px-4 py-3 text-sm font-mono">
                    {message.key || <span className="text-gray-400">null</span>}
                  </td>
                  <td className="px-4 py-3 text-sm">
                    <div className="font-mono whitespace-pre-wrap break-words max-w-md">
                      {valueDisplay}
                    </div>
                    {message.value && message.value.length > 200 && (
                      <button
                        onClick={() => toggleRow(rowId)}
                        className="mt-1 text-blue-600 hover:text-blue-800 text-xs"
                      >
                        {isExpanded ? 'Show less' : 'Show more'}
                      </button>
                    )}
                  </td>
                  <td className="px-4 py-3 text-sm">{message.partition}</td>
                  <td className="px-4 py-3 text-sm font-mono">{message.offset}</td>
                  <td className="px-4 py-3 text-sm">{formatTimestamp(message.timestamp)}</td>
                </tr>
              );
            })}
          </tbody>
        </table>
      </div>
    </div>
  );
}
