import Link from 'next/link';
import { fetchConsumerGroupDetail, formatConsumerGroupState } from '@/lib/api/consumer-groups';
import { RefreshButton } from '@/components/RefreshButton';

export const dynamic = 'force-dynamic';

export default async function ConsumerGroupDetailPage({
  params,
}: {
  params: Promise<{ id: string }>;
}) {
  const { id } = await params;
  const group = await fetchConsumerGroupDetail(decodeURIComponent(id));
  const stateStr = formatConsumerGroupState(group.state);
  const isStable = (stateStr === 'Stable');
  
  return (
    <div>
      <div style={{ marginBottom: '1rem' }}>
        <Link href="/dashboard/consumer-groups" style={{ color: '#0070f3', textDecoration: 'none' }}>
          ← Back to Consumer Groups
        </Link>
      </div>
      
      <div style={{ display: 'flex', justifyContent: 'space-between', alignItems: 'center', marginBottom: '2rem' }}>
        <div>
          <h1 style={{ marginBottom: '0.5rem' }}>{group.groupId}</h1>
          <div style={{ display: 'flex', gap: '1rem', alignItems: 'center' }}>
            <span style={{
              padding: '0.25rem 0.5rem',
              borderRadius: '4px',
              backgroundColor: isStable ? '#d4edda' : '#fff3cd',
              color: isStable ? '#155724' : '#856404',
              fontSize: '0.875rem',
            }}>
              {stateStr}
            </span>
            <span style={{ color: '#666', fontSize: '0.875rem' }}>
              Protocol: {group.protocolType}
            </span>
          </div>
        </div>
        <RefreshButton />
      </div>
      
      <section style={{ marginBottom: '2rem' }}>
        <h2 style={{ marginBottom: '1rem' }}>Members</h2>
        {group.members.length === 0 ? (
          <p>No members in this consumer group.</p>
        ) : (
          <table style={{ width: '100%', borderCollapse: 'collapse' }}>
            <thead>
              <tr style={{ borderBottom: '2px solid #ddd', textAlign: 'left' }}>
                <th style={{ padding: '0.75rem' }}>Member ID</th>
                <th style={{ padding: '0.75rem' }}>Client ID</th>
                <th style={{ padding: '0.75rem' }}>Host</th>
                <th style={{ padding: '0.75rem' }}>Assigned Partitions</th>
              </tr>
            </thead>
            <tbody>
              {group.members.map(member => {
                const assignmentText = member.assignments ? 
                  JSON.stringify(member.assignments).substring(0, 100) : 
                  'None';
                
                return (
                  <tr key={member.memberId} style={{ borderBottom: '1px solid #eee' }}>
                    <td style={{ padding: '0.75rem', fontSize: '0.875rem', fontFamily: 'monospace' }}>
                      {member.memberId}
                    </td>
                    <td style={{ padding: '0.75rem' }}>{member.clientId}</td>
                    <td style={{ padding: '0.75rem' }}>{member.clientHost}</td>
                    <td style={{ padding: '0.75rem', fontSize: '0.875rem' }}>
                      {assignmentText}
                    </td>
                  </tr>
                );
              })}
            </tbody>
          </table>
        )}
      </section>
      
      <section>
        <h2 style={{ marginBottom: '1rem' }}>Partition Lag</h2>
        {group.partitions.length === 0 ? (
          <p>No partition offsets committed.</p>
        ) : (
          <table style={{ width: '100%', borderCollapse: 'collapse' }}>
            <thead>
              <tr style={{ borderBottom: '2px solid #ddd', textAlign: 'left' }}>
                <th style={{ padding: '0.75rem' }}>Topic</th>
                <th style={{ padding: '0.75rem' }}>Partition</th>
                <th style={{ padding: '0.75rem' }}>Committed Offset</th>
                <th style={{ padding: '0.75rem' }}>Lag</th>
              </tr>
            </thead>
            <tbody>
              {group.partitions.map((partition, idx) => (
                <tr key={`${partition.topic}-${partition.partition}-${idx}`} style={{ borderBottom: '1px solid #eee' }}>
                  <td style={{ padding: '0.75rem' }}>{partition.topic}</td>
                  <td style={{ padding: '0.75rem' }}>{partition.partition}</td>
                  <td style={{ padding: '0.75rem', fontFamily: 'monospace' }}>{partition.offset}</td>
                  <td style={{ 
                    padding: '0.75rem', 
                    fontFamily: 'monospace',
                    color: partition.lag > 1000 ? '#d9534f' : partition.lag > 100 ? '#f0ad4e' : '#5cb85c'
                  }}>
                    {partition.lag.toLocaleString()}
                  </td>
                </tr>
              ))}
            </tbody>
          </table>
        )}
      </section>
    </div>
  );
}
