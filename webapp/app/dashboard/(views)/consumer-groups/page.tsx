import Link from 'next/link';
import { fetchConsumerGroups, formatConsumerGroupState } from '@/lib/api/consumer-groups';
import { RefreshButton } from '@/components/RefreshButton';

export const dynamic = 'force-dynamic';

export default async function ConsumerGroupsPage() {
  const groups = await fetchConsumerGroups();
  
  return (
    <div>
      <div style={{ display: 'flex', justifyContent: 'space-between', alignItems: 'center', marginBottom: '2rem' }}>
        <h1>Consumer Groups</h1>
        <RefreshButton />
      </div>
      
      {groups.length === 0 ? (
        <p>No consumer groups found.</p>
      ) : (
        <table style={{ width: '100%', borderCollapse: 'collapse' }}>
          <thead>
            <tr style={{ borderBottom: '2px solid #ddd', textAlign: 'left' }}>
              <th style={{ padding: '0.75rem' }}>Group ID</th>
              <th style={{ padding: '0.75rem' }}>State</th>
              <th style={{ padding: '0.75rem' }}>Members</th>
              <th style={{ padding: '0.75rem' }}>Protocol Type</th>
            </tr>
          </thead>
          <tbody>
            {groups.map(group => {
              const stateStr = formatConsumerGroupState(group.state);
              const isStable = (stateStr === 'Stable');
              return (
                <tr key={group.groupId} style={{ borderBottom: '1px solid #eee' }}>
                  <td style={{ padding: '0.75rem' }}>
                    <Link 
                      href={`/dashboard/consumer-groups/${encodeURIComponent(group.groupId)}`}
                      style={{ color: '#0070f3', textDecoration: 'none' }}
                    >
                      {group.groupId}
                    </Link>
                  </td>
                  <td style={{ padding: '0.75rem' }}>
                    <span style={{
                      padding: '0.25rem 0.5rem',
                      borderRadius: '4px',
                      backgroundColor: isStable ? '#d4edda' : '#fff3cd',
                      color: isStable ? '#155724' : '#856404',
                      fontSize: '0.875rem',
                    }}>
                      {stateStr}
                    </span>
                  </td>
                  <td style={{ padding: '0.75rem' }}>{group.memberCount}</td>
                  <td style={{ padding: '0.75rem' }}>{group.protocolType}</td>
                </tr>
              );
            })}
          </tbody>
        </table>
      )}
    </div>
  );
}
