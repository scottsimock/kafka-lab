import { getKafkaClient } from '@/lib/kafka';

// Type definitions for cluster data
export interface BrokerInfo {
  nodeId: number;
  host: string;
  port: number;
}

export interface ClusterOverview {
  brokers: BrokerInfo[];
  topicCount: number;
  partitionCount: number;
  underReplicatedPartitions: number;
  offlinePartitions: number;
  health: 'healthy' | 'degraded' | 'unhealthy';
}

// Server-side data fetching function for cluster overview
export async function fetchClusterOverview(): Promise<ClusterOverview> {
  const admin = getKafkaClient().admin();
  await admin.connect();
  
  try {
    const metadata = await admin.fetchTopicMetadata();
    
    // Extract unique broker information from partition metadata
    const brokerMap = new Map<number, BrokerInfo>();
    
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
    
    const brokers = Array.from(brokerMap.values()).sort((a, b) => a.nodeId - b.nodeId);
    
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
    
    // Determine cluster health
    let health: 'healthy' | 'degraded' | 'unhealthy';
    if (offlinePartitions > 0) {
      health = 'unhealthy';
    } else if (underReplicatedPartitions > 0) {
      health = 'degraded';
    } else {
      health = 'healthy';
    }
    
    return {
      brokers,
      topicCount,
      partitionCount,
      underReplicatedPartitions,
      offlinePartitions,
      health,
    };
  } finally {
    await admin.disconnect();
  }
}
