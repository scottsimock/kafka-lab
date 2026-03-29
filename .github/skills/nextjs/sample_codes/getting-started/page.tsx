// Server Component: Dashboard page showing Kafka cluster status
// Components in /app are Server Components by default

interface ClusterStatus {
  brokers: number;
  topics: number;
  partitions: number;
  region: string;
}

async function getClusterStatus(): Promise<ClusterStatus> {
  const res = await fetch(`${process.env.KAFKA_API_URL}/cluster/status`, {
    cache: "no-store",
  });

  if (!res.ok) {
    throw new Error("Failed to fetch cluster status");
  }

  return res.json();
}

export default async function DashboardPage() {
  const status = await getClusterStatus();

  return (
    <main className="p-8">
      <h1 className="text-3xl font-bold mb-8">Kafka Lab Dashboard</h1>

      <div className="grid grid-cols-2 md:grid-cols-4 gap-4">
        <StatusCard label="Brokers" value={status.brokers} />
        <StatusCard label="Topics" value={status.topics} />
        <StatusCard label="Partitions" value={status.partitions} />
        <StatusCard label="Region" value={status.region} />
      </div>
    </main>
  );
}

function StatusCard({
  label,
  value,
}: {
  label: string;
  value: string | number;
}) {
  return (
    <div className="rounded-lg border p-6 shadow-sm">
      <p className="text-sm text-gray-500">{label}</p>
      <p className="text-2xl font-semibold mt-1">{value}</p>
    </div>
  );
}
