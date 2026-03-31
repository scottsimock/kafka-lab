import { NextRequest, NextResponse } from 'next/server';
import { getKafkaClient } from '@/lib/kafka';

export const dynamic = 'force-dynamic';

export async function GET(req: NextRequest) {
  const admin = getKafkaClient().admin();
  await admin.connect();
  
  try {
    const metadata = await admin.fetchTopicMetadata();
    
    // Extract unique broker information from partition metadata
    const brokerMap = new Map<number, { nodeId: number; host: string; port: number }>();
    
    for (const topic of metadata.topics) {
      for (const partition of topic.partitions) {
        if (partition.leaderNode) {
          brokerMap.set(partition.leaderNode.id, {
            nodeId: partition.leaderNode.id,
            host: partition.leaderNode.host,
            port: partition.leaderNode.port,
          });
        }
        
        // Also collect replica nodes
        if (partition.replicaNodes) {
          for (const node of partition.replicaNodes) {
            brokerMap.set(node.id, {
              nodeId: node.id,
              host: node.host,
              port: node.port,
            });
          }
        }
      }
    }
    
    const brokers = Array.from(brokerMap.values());
    
    // Count topics and partitions
    const topicCount = metadata.topics.length;
    const partitionCount = metadata.topics.reduce(
      (total, topic) => total + topic.partitions.length,
      0
    );
    
    // Find under-replicated and offline partitions
    let underReplicatedPartitions = 0;
    let offlinePartitions = 0;
    
    for (const topic of metadata.topics) {
      for (const partition of topic.partitions) {
        const replicationFactor = partition.replicas.length;
        const inSyncReplicas = partition.isr.length;
        
        if (inSyncReplicas < replicationFactor) {
          underReplicatedPartitions++;
        }
        
        if (partition.leader === -1) {
          offlinePartitions++;
        }
      }
    }
    
    return NextResponse.json({
      brokers,
      topicCount,
      partitionCount,
      underReplicatedPartitions,
      offlinePartitions,
    });
  } catch (error) {
    const message = error instanceof Error ? error.message : 'Unknown error';
    return NextResponse.json({ error: message }, { status: 500 });
  } finally {
    await admin.disconnect();
  }
}
