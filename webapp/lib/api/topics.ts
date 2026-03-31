import { getKafkaClient } from '@/lib/kafka';

export interface TopicSummary {
  name: string;
  partitionCount: number;
  replicationFactor: number;
}

export interface PartitionDetail {
  partition: number;
  leader: number;
  replicas: number[];
  isr: number[];
  low: string;
  high: string;
}

export interface TopicDetail {
  name: string;
  partitions: PartitionDetail[];
  isInternal: boolean;
}

// Fetch all topics with partition count and replication factor
export async function fetchTopics(): Promise<TopicSummary[]> {
  const admin = getKafkaClient().admin();
  await admin.connect();
  
  try {
    const metadata = await admin.fetchTopicMetadata();
    
    return metadata.topics.map(topic => ({
      name: topic.name,
      partitionCount: topic.partitions.length,
      replicationFactor: topic.partitions[0]?.replicas.length || 0,
    }));
  } finally {
    await admin.disconnect();
  }
}

// Fetch full metadata, offsets, and config for one topic
export async function fetchTopicDetail(name: string): Promise<TopicDetail> {
  const admin = getKafkaClient().admin();
  await admin.connect();
  
  try {
    const [metadata, offsets] = await Promise.all([
      admin.fetchTopicMetadata({ topics: [name] }),
      admin.fetchTopicOffsets(name),
    ]);
    
    const topic = metadata.topics.find(t => t.name === name);
    if (!topic) {
      throw new Error('Topic not found');
    }
    
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
    
    return {
      name: topic.name,
      partitions,
      isInternal: topic.isInternal || false,
    };
  } finally {
    await admin.disconnect();
  }
}
