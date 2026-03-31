export default function DashboardLayout({
  children,
}: {
  children: React.ReactNode;
}) {
  return (
    <div style={{ display: 'flex', minHeight: 'calc(100vh - 4rem)' }}>
      <aside style={{ width: '200px', padding: '1rem', borderRight: '1px solid #ddd' }}>
        <nav>
          <ul style={{ listStyle: 'none', padding: 0 }}>
            <li style={{ marginBottom: '0.5rem' }}>
              <a href="/dashboard/overview">Overview</a>
            </li>
            <li style={{ marginBottom: '0.5rem' }}>
              <a href="/dashboard/topics">Topics</a>
            </li>
            <li style={{ marginBottom: '0.5rem' }}>
              <a href="/dashboard/consumer-groups">Consumer Groups</a>
            </li>
            <li style={{ marginBottom: '0.5rem' }}>
              <a href="/dashboard/messages">Messages</a>
            </li>
            <li style={{ marginBottom: '0.5rem' }}>
              <a href="/dashboard/schemas">Schemas</a>
            </li>
          </ul>
        </nav>
      </aside>
      <main style={{ flex: 1, padding: '2rem' }}>
        {children}
      </main>
    </div>
  );
}
