'use client';

import { useState, FormEvent } from 'react';

interface ProduceFormProps {
  topic: string;
  onSuccess?: () => void;
}

export function ProduceForm({ topic, onSuccess }: ProduceFormProps) {
  const [key, setKey] = useState('');
  const [value, setValue] = useState('');
  const [loading, setLoading] = useState(false);
  const [error, setError] = useState<string | null>(null);
  const [success, setSuccess] = useState(false);

  const handleSubmit = async (e: FormEvent) => {
    e.preventDefault();
    
    if (!value.trim()) {
      setError('Value is required');
      return;
    }

    setLoading(true);
    setError(null);
    setSuccess(false);

    try {
      const response = await fetch('/api/messages/produce', {
        method: 'POST',
        headers: {
          'Content-Type': 'application/json',
        },
        body: JSON.stringify({
          topic,
          key: key || undefined,
          value,
        }),
      });

      if (!response.ok) {
        const data = await response.json();
        throw new Error(data.error || 'Failed to produce message');
      }

      // Clear form on success
      setKey('');
      setValue('');
      setSuccess(true);
      
      // Call success callback
      if (onSuccess) {
        onSuccess();
      }

      // Clear success message after 3 seconds
      setTimeout(() => setSuccess(false), 3000);
    } catch (err) {
      setError(err instanceof Error ? err.message : 'Failed to produce message');
    } finally {
      setLoading(false);
    }
  };

  return (
    <div className="border border-gray-300 rounded-lg p-4">
      <h2 className="text-lg font-semibold mb-4">Produce Message</h2>
      
      <form onSubmit={handleSubmit} className="space-y-4">
        <div>
          <label htmlFor="topic-input" className="block text-sm font-medium mb-1">
            Topic
          </label>
          <input
            id="topic-input"
            type="text"
            value={topic}
            disabled
            className="w-full px-3 py-2 border border-gray-300 rounded-md bg-gray-100"
          />
        </div>

        <div>
          <label htmlFor="key-input" className="block text-sm font-medium mb-1">
            Key (optional)
          </label>
          <input
            id="key-input"
            type="text"
            value={key}
            onChange={(e) => setKey(e.target.value)}
            placeholder="Message key"
            className="w-full px-3 py-2 border border-gray-300 rounded-md"
          />
        </div>

        <div>
          <label htmlFor="value-input" className="block text-sm font-medium mb-1">
            Value *
          </label>
          <textarea
            id="value-input"
            value={value}
            onChange={(e) => setValue(e.target.value)}
            placeholder="Message value (JSON or plain text)"
            rows={4}
            required
            className="w-full px-3 py-2 border border-gray-300 rounded-md"
          />
        </div>

        {error && (
          <div className="p-3 bg-red-100 text-red-700 rounded-md text-sm">
            {error}
          </div>
        )}

        {success && (
          <div className="p-3 bg-green-100 text-green-700 rounded-md text-sm">
            Message produced successfully!
          </div>
        )}

        <button
          type="submit"
          disabled={loading}
          className="px-4 py-2 bg-green-600 text-white rounded-md hover:bg-green-700 disabled:bg-gray-400"
        >
          {loading ? 'Producing...' : 'Produce Message'}
        </button>
      </form>
    </div>
  );
}
