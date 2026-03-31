import type { Metadata } from 'next';

export const metadata: Metadata = {
  title: 'Kafka Lab',
  description: 'Confluent Kafka Management UI',
};

export default function RootLayout({
  children,
}: {
  children: React.ReactNode;
}) {
  return (
    <html lang="en">
      <body>
        <nav style={{ padding: '1rem', borderBottom: '1px solid #ddd' }}>
          <a href="/" style={{ fontWeight: 'bold', marginRight: '2rem' }}>Kafka Lab</a>
          <a href="/dashboard/overview" style={{ marginRight: '1rem' }}>Dashboard</a>
        </nav>
        {children}
      </body>
    </html>
  );
}
