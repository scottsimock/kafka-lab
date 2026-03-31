'use client';

import { useState, useEffect } from 'react';
import { ProduceForm } from './ProduceForm';
import { MessageTable } from './MessageTable';
import { StreamingConsumer } from './StreamingConsumer';

interface Message {
  key: string | undefined;
  value: string | undefined;
  partition: number;
  offset: string;
  timestamp: string;
  headers?: Record<string, string>;
}

export function MessageBrowser() {
  const [topics, setTopics] = useState<string[]>([]);
  const [selectedTopic, setSelectedTopic] = useState<string>('');
  const [messages, setMessages] = useState<Message[]>([]);
  const [loading, setLoading] = useState(true);
  const [error, setError] = useState<string | null>(null);

  // Fetch topics on mount
  useEffect(() => {
    async function fetchTopics() {
      try {
        const response = await fetch('/api/topics');
        if (!response.ok) {
          throw new Error('Failed to fetch topics');
        }
        const data = await response.json();
        setTopics(data.topics.map((t: { name: string }) => t.name));
        if (data.topics.length > 0) {
          setSelectedTopic(data.topics[0].name);
        }
      } catch (err) {
        setError(err instanceof Error ? err.message : 'Failed to load topics');
      } finally {
        setLoading(false);
      }
    }

    fetchTopics();
  }, []);

  // Fetch messages when topic changes
  const handleFetchMessages = async () => {
    if (!selectedTopic) return;

    try {
      setLoading(true);
      const response = await fetch(
        `/api/messages/consume?topic=${encodeURIComponent(selectedTopic)}&limit=20`
      );
      if (!response.ok) {
        throw new Error('Failed to fetch messages');
      }
      const data = await response.json();
      setMessages(data.messages);
    } catch (err) {
      setError(err instanceof Error ? err.message : 'Failed to load messages');
    } finally {
      setLoading(false);
    }
  };

  // Handle new streaming messages
  const handleStreamMessage = (message: Message) => {
    setMessages((prev) => [message, ...prev]);
  };

  // Handle produce success
  const handleProduceSuccess = () => {
    // Optionally refresh messages or let streaming handle it
    handleFetchMessages();
  };

  if (loading && topics.length === 0) {
    return <div className="p-4">Loading topics...</div>;
  }

  if (error && topics.length === 0) {
    return <div className="p-4 text-red-600">Error: {error}</div>;
  }

  return (
    <div className="space-y-6 p-6">
      <div>
        <h1 className="text-2xl font-bold mb-4">Message Browser</h1>
        
        {/* Topic Selector */}
        <div className="mb-6">
          <label htmlFor="topic-select" className="block text-sm font-medium mb-2">
            Select Topic
          </label>
          <select
            id="topic-select"
            value={selectedTopic}
            onChange={(e) => {
              setSelectedTopic(e.target.value);
              setMessages([]);
            }}
            className="px-3 py-2 border border-gray-300 rounded-md w-full max-w-md"
          >
            {topics.length === 0 && (
              <option value="">No topics available</option>
            )}
            {topics.map((topic) => (
              <option key={topic} value={topic}>
                {topic}
              </option>
            ))}
          </select>
        </div>
      </div>

      {/* Produce Form */}
      {selectedTopic && (
        <ProduceForm topic={selectedTopic} onSuccess={handleProduceSuccess} />
      )}

      {/* Streaming Controls and Fetch Button */}
      {selectedTopic && (
        <div className="flex gap-4 items-center">
          <button
            onClick={handleFetchMessages}
            disabled={loading}
            className="px-4 py-2 bg-blue-600 text-white rounded-md hover:bg-blue-700 disabled:bg-gray-400"
          >
            {loading ? 'Fetching...' : 'Fetch Messages'}
          </button>
          <StreamingConsumer
            topic={selectedTopic}
            onMessage={handleStreamMessage}
          />
        </div>
      )}

      {/* Message Display */}
      <MessageTable messages={messages} />
    </div>
  );
}
