import { NextRequest, NextResponse } from 'next/server';
import { getKafkaClient } from '@/lib/kafka';

export const dynamic = 'force-dynamic';

export async function GET(req: NextRequest) {
  const admin = getKafkaClient().admin();
  await admin.connect();
  
  try {
    const metadata = await admin.fetchTopicMetadata();
    
    const topics = metadata.topics.map(topic => ({
      name: topic.name,
      partitionCount: topic.partitions.length,
      replicationFactor: topic.partitions[0]?.replicas.length || 0,
    }));
    
    return NextResponse.json({ topics });
  } catch (error) {
    const message = error instanceof Error ? error.message : 'Unknown error';
    return NextResponse.json({ error: message }, { status: 500 });
  } finally {
    await admin.disconnect();
  }
}

export async function POST() {
  return NextResponse.json({ status: 'not implemented' });
}
