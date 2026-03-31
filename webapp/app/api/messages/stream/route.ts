import { NextRequest, NextResponse } from 'next/server';
import { getKafkaClient } from '@/lib/kafka';

export const dynamic = 'force-dynamic';

export async function GET(req: NextRequest) {
  const topic = req.nextUrl.searchParams.get('topic');

  if (!topic) {
    return NextResponse.json(
      { error: 'topic parameter is required' },
      { status: 400 }
    );
  }

  const encoder = new TextEncoder();

  const stream = new ReadableStream({
    async start(controller) {
      const consumer = getKafkaClient().consumer({
        kafkaJS: {
          groupId: `kafka-lab-stream-${Date.now()}`,
        },
      });

      try {
        await consumer.connect();
        await consumer.subscribe({ topic });

        // Handle client disconnect
        req.signal.addEventListener('abort', async () => {
          try {
            await consumer.disconnect();
          } catch (error) {
            console.error('Error disconnecting consumer on abort:', error);
          }
          controller.close();
        });

        await consumer.run({
          eachMessage: async ({ message, partition }) => {
            try {
              const data = JSON.stringify({
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

              controller.enqueue(encoder.encode(`data: ${data}\n\n`));
            } catch (error) {
              console.error('Error encoding message:', error);
            }
          },
        });
      } catch (error) {
        console.error('Error in SSE stream:', error);
        controller.error(error);
      }
    },
  });

  return new Response(stream, {
    headers: {
      'Content-Type': 'text/event-stream',
      'Cache-Control': 'no-cache',
      'Connection': 'keep-alive',
    },
  });
}
