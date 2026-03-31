import { NextRequest, NextResponse } from 'next/server';
import { getKafkaClient } from '@/lib/kafka';

export const dynamic = 'force-dynamic';

export async function GET(req: NextRequest) {
  const admin = getKafkaClient().admin();
  await admin.connect();
  
  try {
    const groups = await admin.listGroups();
    
    // Get group IDs for description
    const groupIds = groups.groups.map(group => group.groupId);
    
    if (groupIds.length === 0) {
      return NextResponse.json({ groups: [] });
    }
    
    const descriptions = await admin.describeGroups(groupIds);
    
    const groupsWithDetails = descriptions.groups.map(group => ({
      groupId: group.groupId,
      state: group.state,
      protocolType: group.protocolType,
      memberCount: group.members.length,
    }));
    
    return NextResponse.json({ groups: groupsWithDetails });
  } catch (error) {
    const message = error instanceof Error ? error.message : 'Unknown error';
    return NextResponse.json({ error: message }, { status: 500 });
  } finally {
    await admin.disconnect();
  }
}
