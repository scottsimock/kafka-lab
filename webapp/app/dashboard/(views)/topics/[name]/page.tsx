import Link from 'next/link';
import { fetchTopicDetail } from '@/lib/api/topics';

export const dynamic = 'force-dynamic';

export default async function TopicDetailPage({
  params,
}: {
  params: Promise<{ name: string }>;
}) {
  const { name } = await params;
  const decodedName = decodeURIComponent(name);
  const topic = await fetchTopicDetail(decodedName);
  
  return (
    <div>
      <Link href="/dashboard/topics" style={{ color: '#0070f3', textDecoration: 'none' }}>
        ← Back to Topics
      </Link>
      
      <h1 style={{ marginTop: '1rem' }}>{topic.name}</h1>
      
      <div style={{ marginTop: '1rem' }}>
        <p><strong>Partitions:</strong> {topic.partitions.length}</p>
        <p><strong>Replication Factor:</strong> {topic.partitions[0]?.replicas.length || 0}</p>
        <p><strong>Internal:</strong> {topic.isInternal ? 'Yes' : 'No'}</p>
      </div>
      
      <h2 style={{ marginTop: '2rem' }}>Partition Details</h2>
      <table style={{ width: '100%', borderCollapse: 'collapse', marginTop: '1rem' }}>
        <thead>
          <tr style={{ borderBottom: '2px solid #333' }}>
            <th style={{ textAlign: 'left', padding: '0.5rem' }}>Partition ID</th>
            <th style={{ textAlign: 'right', padding: '0.5rem' }}>Leader</th>
            <th style={{ textAlign: 'right', padding: '0.5rem' }}>Replicas</th>
            <th style={{ textAlign: 'right', padding: '0.5rem' }}>ISR</th>
            <th style={{ textAlign: 'right', padding: '0.5rem' }}>Begin Offset</th>
            <th style={{ textAlign: 'right', padding: '0.5rem' }}>End Offset</th>
          </tr>
        </thead>
        <tbody>
          {topic.partitions.map((partition) => (
            <tr key={partition.partition} style={{ borderBottom: '1px solid #ddd' }}>
              <td style={{ padding: '0.5rem' }}>{partition.partition}</td>
              <td style={{ textAlign: 'right', padding: '0.5rem' }}>{partition.leader}</td>
              <td style={{ textAlign: 'right', padding: '0.5rem' }}>{partition.replicas.join(', ')}</td>
              <td style={{ textAlign: 'right', padding: '0.5rem' }}>{partition.isr.join(', ')}</td>
              <td style={{ textAlign: 'right', padding: '0.5rem' }}>{partition.low}</td>
              <td style={{ textAlign: 'right', padding: '0.5rem' }}>{partition.high}</td>
            </tr>
          ))}
        </tbody>
      </table>
    </div>
  );
}
