import { fetchClusterOverview } from '@/lib/api/cluster';

export const dynamic = 'force-dynamic';

export default async function ClusterOverviewPage() {
  const data = await fetchClusterOverview();

  // Determine health badge style
  const healthStyles: Record<string, { color: string; background: string }> = {
    healthy: { color: '#166534', background: '#dcfce7' },
    degraded: { color: '#92400e', background: '#fef3c7' },
    unhealthy: { color: '#991b1b', background: '#fee2e2' },
  };

  const healthStyle = healthStyles[data.health];

  return (
    <div>
      <header style={{ marginBottom: '2rem' }}>
        <h1 style={{ fontSize: '2rem', fontWeight: 'bold', marginBottom: '0.5rem' }}>Cluster Overview</h1>
        <div style={{ display: 'flex', alignItems: 'center', gap: '0.5rem' }}>
          <span style={{ fontSize: '0.875rem', color: '#6b7280' }}>Cluster Health:</span>
          <span
            style={{
              display: 'inline-block',
              padding: '0.25rem 0.75rem',
              borderRadius: '0.25rem',
              fontSize: '0.875rem',
              fontWeight: '600',
              color: healthStyle.color,
              backgroundColor: healthStyle.background,
            }}
          >
            {data.health.charAt(0).toUpperCase() + data.health.slice(1)}
          </span>
        </div>
      </header>

      <section style={{ marginBottom: '2rem' }}>
        <h2 style={{ fontSize: '1.25rem', fontWeight: '600', marginBottom: '1rem' }}>Summary</h2>
        <div style={{ display: 'grid', gridTemplateColumns: 'repeat(auto-fit, minmax(200px, 1fr))', gap: '1rem' }}>
          <div style={{ padding: '1rem', border: '1px solid #e5e7eb', borderRadius: '0.5rem' }}>
            <div style={{ fontSize: '0.875rem', color: '#6b7280', marginBottom: '0.25rem' }}>Total Topics</div>
            <div style={{ fontSize: '1.5rem', fontWeight: '700' }}>{data.topicCount}</div>
          </div>
          <div style={{ padding: '1rem', border: '1px solid #e5e7eb', borderRadius: '0.5rem' }}>
            <div style={{ fontSize: '0.875rem', color: '#6b7280', marginBottom: '0.25rem' }}>Total Partitions</div>
            <div style={{ fontSize: '1.5rem', fontWeight: '700' }}>{data.partitionCount}</div>
          </div>
          <div style={{ padding: '1rem', border: '1px solid #e5e7eb', borderRadius: '0.5rem' }}>
            <div style={{ fontSize: '0.875rem', color: '#6b7280', marginBottom: '0.25rem' }}>Under-Replicated</div>
            <div style={{ fontSize: '1.5rem', fontWeight: '700', color: data.underReplicatedPartitions > 0 ? '#d97706' : '#059669' }}>
              {data.underReplicatedPartitions}
            </div>
          </div>
          <div style={{ padding: '1rem', border: '1px solid #e5e7eb', borderRadius: '0.5rem' }}>
            <div style={{ fontSize: '0.875rem', color: '#6b7280', marginBottom: '0.25rem' }}>Offline Partitions</div>
            <div style={{ fontSize: '1.5rem', fontWeight: '700', color: data.offlinePartitions > 0 ? '#dc2626' : '#059669' }}>
              {data.offlinePartitions}
            </div>
          </div>
        </div>
      </section>

      <section>
        <h2 style={{ fontSize: '1.25rem', fontWeight: '600', marginBottom: '1rem' }}>Brokers</h2>
        <table style={{ width: '100%', borderCollapse: 'collapse', border: '1px solid #e5e7eb' }}>
          <thead>
            <tr style={{ backgroundColor: '#f9fafb' }}>
              <th style={{ padding: '0.75rem', textAlign: 'left', fontWeight: '600', borderBottom: '1px solid #e5e7eb' }}>Node ID</th>
              <th style={{ padding: '0.75rem', textAlign: 'left', fontWeight: '600', borderBottom: '1px solid #e5e7eb' }}>Host</th>
              <th style={{ padding: '0.75rem', textAlign: 'left', fontWeight: '600', borderBottom: '1px solid #e5e7eb' }}>Port</th>
              <th style={{ padding: '0.75rem', textAlign: 'left', fontWeight: '600', borderBottom: '1px solid #e5e7eb' }}>Status</th>
            </tr>
          </thead>
          <tbody>
            {data.brokers.map((broker) => (
              <tr key={broker.nodeId} style={{ borderBottom: '1px solid #e5e7eb' }}>
                <td style={{ padding: '0.75rem' }}>{broker.nodeId}</td>
                <td style={{ padding: '0.75rem', fontFamily: 'monospace' }}>{broker.host}</td>
                <td style={{ padding: '0.75rem' }}>{broker.port}</td>
                <td style={{ padding: '0.75rem' }}>
                  <span
                    style={{
                      display: 'inline-block',
                      width: '8px',
                      height: '8px',
                      borderRadius: '50%',
                      backgroundColor: '#10b981',
                      marginRight: '0.5rem',
                    }}
                  />
                  <span style={{ color: '#059669' }}>Online</span>
                </td>
              </tr>
            ))}
          </tbody>
        </table>
      </section>
    </div>
  );
}
