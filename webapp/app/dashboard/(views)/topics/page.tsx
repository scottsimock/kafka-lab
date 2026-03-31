import Link from 'next/link';
import { fetchTopics } from '@/lib/api/topics';

export const dynamic = 'force-dynamic';

export default async function TopicsPage() {
  const topics = await fetchTopics();
  
  return (
    <div>
      <h1>Topics</h1>
      <table style={{ width: '100%', borderCollapse: 'collapse', marginTop: '1rem' }}>
        <thead>
          <tr style={{ borderBottom: '2px solid #333' }}>
            <th style={{ textAlign: 'left', padding: '0.5rem' }}>Topic Name</th>
            <th style={{ textAlign: 'right', padding: '0.5rem' }}>Partitions</th>
            <th style={{ textAlign: 'right', padding: '0.5rem' }}>Replication Factor</th>
          </tr>
        </thead>
        <tbody>
          {topics.map((topic) => (
            <tr key={topic.name} style={{ borderBottom: '1px solid #ddd' }}>
              <td style={{ padding: '0.5rem' }}>
                <Link href={`/dashboard/topics/${encodeURIComponent(topic.name)}`}>
                  {topic.name}
                </Link>
              </td>
              <td style={{ textAlign: 'right', padding: '0.5rem' }}>{topic.partitionCount}</td>
              <td style={{ textAlign: 'right', padding: '0.5rem' }}>{topic.replicationFactor}</td>
            </tr>
          ))}
        </tbody>
      </table>
      {topics.length === 0 && (
        <p style={{ marginTop: '1rem', color: '#666' }}>No topics found</p>
      )}
    </div>
  );
}
