import { NextRequest, NextResponse } from 'next/server';
import { getKafkaClient } from '@/lib/kafka';

export const dynamic = 'force-dynamic';

export async function GET(
  req: NextRequest,
  { params }: { params: Promise<{ id: string }> }
) {
  const { id } = await params;
  const admin = getKafkaClient().admin();
  await admin.connect();
  
  try {
    const descriptions = await admin.describeGroups([id]);
    
    if (descriptions.groups.length === 0) {
      return NextResponse.json({ error: 'Consumer group not found' }, { status: 404 });
    }
    
    const group = descriptions.groups[0];
    
    // Fetch offsets for this consumer group
    const offsetsResponse = await admin.fetchOffsets({ groupId: id });
    
    // Calculate lag for each partition
    const partitionsWithLag = await Promise.all(
      offsetsResponse.map(async topicOffset => {
        const topicOffsets = await admin.fetchTopicOffsets(topicOffset.topic);
        
        return topicOffset.partitions.map(partition => {
          const endOffset = topicOffsets.find(
            o => o.partition === partition.partition
          );
          
          const committedOffset = parseInt(partition.offset, 10);
          const highWaterMark = endOffset ? parseInt(endOffset.high, 10) : 0;
          const lag = Math.max(0, highWaterMark - committedOffset);
          
          return {
            topic: topicOffset.topic,
            partition: partition.partition,
            offset: partition.offset,
            lag,
            metadata: partition.metadata,
          };
        });
      })
    );
    
    const flatPartitions = partitionsWithLag.flat();
    
    // Build member assignments
    const members = group.members.map(member => ({
      memberId: member.memberId,
      clientId: member.clientId,
      clientHost: member.clientHost,
      assignments: member.memberAssignment,
    }));
    
    return NextResponse.json({
      groupId: group.groupId,
      state: group.state,
      protocolType: group.protocolType,
      protocol: group.protocol,
      members,
      partitions: flatPartitions,
    });
  } catch (error) {
    const message = error instanceof Error ? error.message : 'Unknown error';
    return NextResponse.json({ error: message }, { status: 500 });
  } finally {
    await admin.disconnect();
  }
}
