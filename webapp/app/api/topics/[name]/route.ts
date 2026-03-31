import { NextRequest, NextResponse } from 'next/server';
import { getKafkaClient } from '@/lib/kafka';

export const dynamic = 'force-dynamic';

export async function GET(
  req: NextRequest,
  { params }: { params: Promise<{ name: string }> }
) {
  const { name } = await params;
  const admin = getKafkaClient().admin();
  await admin.connect();
  
  try {
    const [metadata, offsets] = await Promise.all([
      admin.fetchTopicMetadata({ topics: [name] }),
      admin.fetchTopicOffsets(name),
    ]);
    
    const topic = metadata.topics.find(t => t.name === name);
    if (!topic) {
      return NextResponse.json({ error: 'Topic not found' }, { status: 404 });
    }
    
    // Build partition details with offsets
    const partitions = topic.partitions.map(partition => {
      const offset = offsets.find(o => o.partition === partition.partitionId);
      return {
        partition: partition.partitionId,
        leader: partition.leader,
        replicas: partition.replicas,
        isr: partition.isr,
        low: offset?.low || '0',
        high: offset?.high || '0',
      };
    });
    
    return NextResponse.json({
      name: topic.name,
      partitions,
      isInternal: topic.isInternal || false,
    });
  } catch (error) {
    const message = error instanceof Error ? error.message : 'Unknown error';
    return NextResponse.json({ error: message }, { status: 500 });
  } finally {
    await admin.disconnect();
  }
}

export async function DELETE() {
  return NextResponse.json({ status: 'not implemented' });
}
