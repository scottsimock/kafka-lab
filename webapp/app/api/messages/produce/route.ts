import { NextRequest, NextResponse } from 'next/server';
import { getKafkaClient } from '@/lib/kafka';

export const dynamic = 'force-dynamic';

export async function POST(req: NextRequest) {
  try {
    const body = await req.json();
    const { topic, key, value, headers } = body;

    // Validate required fields
    if (!topic || typeof topic !== 'string') {
      return NextResponse.json(
        { error: 'topic is required and must be a string' },
        { status: 400 }
      );
    }

    if (!value) {
      return NextResponse.json(
        { error: 'value is required' },
        { status: 400 }
      );
    }

    const producer = getKafkaClient().producer();
    await producer.connect();

    try {
      const result = await producer.send({
        topic,
        messages: [
          {
            key: key ? String(key) : undefined,
            value: String(value),
            headers: headers || {},
          },
        ],
      });

      return NextResponse.json({ result });
    } finally {
      await producer.disconnect();
    }
  } catch (error) {
    console.error('Error producing message:', error);
    return NextResponse.json(
      { error: error instanceof Error ? error.message : 'Failed to produce message' },
      { status: 500 }
    );
  }
}
