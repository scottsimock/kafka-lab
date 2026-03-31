import { getKafkaClient } from '@/lib/kafka';

export interface ConsumerGroupSummary {
  groupId: string;
  state: string;
  protocolType: string;
  memberCount: number;
}

export interface ConsumerGroupMember {
  memberId: string;
  clientId: string;
  clientHost: string;
  assignments: any;
}

export interface ConsumerGroupPartition {
  topic: string;
  partition: number;
  offset: string;
  lag: number;
  metadata: string | null;
}

export interface ConsumerGroupDetail {
  groupId: string;
  state: string;
  protocolType: string;
  protocol: string;
  members: ConsumerGroupMember[];
  partitions: ConsumerGroupPartition[];
}

export function formatConsumerGroupState(state: string | number): string {
  const stateStr = String(state).toUpperCase();
  // Normalize to title case for UI consistency
  switch (stateStr) {
    case 'STABLE':
      return 'Stable';
    case 'REBALANCING':
      return 'Rebalancing';
    case 'EMPTY':
      return 'Empty';
    case 'DEAD':
      return 'Dead';
    default:
      return stateStr.charAt(0) + stateStr.slice(1).toLowerCase();
  }
}

export async function fetchConsumerGroups(): Promise<ConsumerGroupSummary[]> {
  const admin = getKafkaClient().admin();
  await admin.connect();
  
  try {
    const groups = await admin.listGroups();
    
    const groupIds = groups.groups.map(group => group.groupId);
    
    if (groupIds.length === 0) {
      return [];
    }
    
    const descriptions = await admin.describeGroups(groupIds);
    
    return descriptions.groups.map(group => ({
      groupId: group.groupId,
      state: String(group.state),
      protocolType: group.protocolType,
      memberCount: group.members.length,
    }));
  } finally {
    await admin.disconnect();
  }
}

export async function fetchConsumerGroupDetail(groupId: string): Promise<ConsumerGroupDetail> {
  const admin = getKafkaClient().admin();
  await admin.connect();
  
  try {
    const descriptions = await admin.describeGroups([groupId]);
    
    if (descriptions.groups.length === 0) {
      throw new Error('Consumer group not found');
    }
    
    const group = descriptions.groups[0];
    
    // Fetch offsets for this consumer group
    const offsetsResponse = await admin.fetchOffsets({ groupId });
    
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
    
    return {
      groupId: group.groupId,
      state: String(group.state),
      protocolType: group.protocolType,
      protocol: group.protocol,
      members,
      partitions: flatPartitions,
    };
  } finally {
    await admin.disconnect();
  }
}
