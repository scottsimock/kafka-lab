import { NextRequest, NextResponse } from 'next/server';
import { getKafkaClient } from '@/lib/kafka';

export const dynamic = 'force-dynamic';

export async function GET(req: NextRequest) {
  try {
    const searchParams = req.nextUrl.searchParams;
    const topic = searchParams.get('topic');
    const limitParam = searchParams.get('limit');
    const limit = limitParam ? parseInt(limitParam, 10) : 20;

    // Validate required parameters
    if (!topic) {
      return NextResponse.json(
        { error: 'topic parameter is required' },
        { status: 400 }
      );
    }

    if (isNaN(limit) || limit <= 0) {
      return NextResponse.json(
        { error: 'limit must be a positive number' },
        { status: 400 }
      );
    }

    // Create consumer with unique group ID
    const consumer = getKafkaClient().consumer({
      kafkaJS: {
        groupId: `kafka-lab-browser-${Date.now()}`,
      },
    });

    await consumer.connect();

    try {
      await consumer.subscribe({ topic });

      const messages: Array<{
        key: string | undefined;
        value: string | undefined;
        partition: number;
        offset: string;
        timestamp: string;
        headers?: Record<string, string>;
      }> = [];

      // Collect messages with timeout
      await new Promise<void>((resolve) => {
        let resolved = false;

        const finish = () => {
          if (!resolved) {
            resolved = true;
            resolve();
          }
        };

        consumer.run({
          eachMessage: async ({ message, partition }) => {
            if (resolved) return;

            messages.push({
              key: message.key?.toString(),
              value: message.value?.toString(),
              partition,
              offset: message.offset,
              timestamp: message.timestamp,
              headers: message.headers
                ? Object.fromEntries(
                    Object.entries(message.headers).map(([k, v]) => [
                      k,
                      v?.toString() || '',
                    ])
                  )
                : undefined,
            });

            if (messages.length >= limit) {
              finish();
            }
          },
        });

        // Timeout after 5 seconds
        setTimeout(finish, 5000);
      });

      return NextResponse.json({ messages });
    } finally {
      await consumer.disconnect();
    }
  } catch (error) {
    console.error('Error consuming messages:', error);
    return NextResponse.json(
      { error: error instanceof Error ? error.message : 'Failed to consume messages' },
      { status: 500 }
    );
  }
}
