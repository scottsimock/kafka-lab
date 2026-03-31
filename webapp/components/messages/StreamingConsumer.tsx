'use client';

import { useState, useEffect, useRef } from 'react';

interface Message {
  key: string | undefined;
  value: string | undefined;
  partition: number;
  offset: string;
  timestamp: string;
  headers?: Record<string, string>;
}

interface StreamingConsumerProps {
  topic: string;
  onMessage: (message: Message) => void;
}

type ConnectionStatus = 'disconnected' | 'connecting' | 'connected';

export function StreamingConsumer({ topic, onMessage }: StreamingConsumerProps) {
  const [status, setStatus] = useState<ConnectionStatus>('disconnected');
  const [error, setError] = useState<string | null>(null);
  const eventSourceRef = useRef<EventSource | null>(null);

  // Cleanup on unmount or topic change
  useEffect(() => {
    return () => {
      if (eventSourceRef.current) {
        eventSourceRef.current.close();
        eventSourceRef.current = null;
      }
    };
  }, [topic]);

  const startStreaming = () => {
    if (eventSourceRef.current) {
      return; // Already streaming
    }

    setStatus('connecting');
    setError(null);

    const eventSource = new EventSource(
      `/api/messages/stream?topic=${encodeURIComponent(topic)}`
    );

    eventSource.onopen = () => {
      setStatus('connected');
      setError(null);
    };

    eventSource.onmessage = (event) => {
      try {
        const message = JSON.parse(event.data);
        onMessage(message);
      } catch (err) {
        console.error('Failed to parse message:', err);
      }
    };

    eventSource.onerror = (err) => {
      console.error('EventSource error:', err);
      setError('Connection error');
      setStatus('disconnected');
      eventSource.close();
      eventSourceRef.current = null;
    };

    eventSourceRef.current = eventSource;
  };

  const stopStreaming = () => {
    if (eventSourceRef.current) {
      eventSourceRef.current.close();
      eventSourceRef.current = null;
      setStatus('disconnected');
      setError(null);
    }
  };

  const getStatusColor = () => {
    switch (status) {
      case 'connected':
        return 'text-green-600';
      case 'connecting':
        return 'text-yellow-600';
      case 'disconnected':
        return 'text-gray-600';
      default:
        return 'text-gray-600';
    }
  };

  const getStatusText = () => {
    switch (status) {
      case 'connected':
        return 'Connected';
      case 'connecting':
        return 'Connecting...';
      case 'disconnected':
        return 'Disconnected';
      default:
        return 'Unknown';
    }
  };

  return (
    <div className="flex items-center gap-4">
      <button
        onClick={status === 'connected' ? stopStreaming : startStreaming}
        disabled={status === 'connecting'}
        className={`px-4 py-2 rounded-md text-white ${
          status === 'connected'
            ? 'bg-red-600 hover:bg-red-700'
            : 'bg-green-600 hover:bg-green-700'
        } disabled:bg-gray-400`}
      >
        {status === 'connected' ? 'Stop Streaming' : 'Start Streaming'}
      </button>

      <div className="flex items-center gap-2">
        <div className={`w-2 h-2 rounded-full ${
          status === 'connected' ? 'bg-green-600' :
          status === 'connecting' ? 'bg-yellow-600' :
          'bg-gray-400'
        }`} />
        <span className={`text-sm font-medium ${getStatusColor()}`}>
          {getStatusText()}
        </span>
      </div>

      {error && (
        <span className="text-sm text-red-600">{error}</span>
      )}
    </div>
  );
}
