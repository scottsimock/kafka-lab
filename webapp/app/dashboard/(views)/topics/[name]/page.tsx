export default async function TopicDetailPage({
  params,
}: {
  params: Promise<{ name: string }>;
}) {
  const { name } = await params;
  
  return (
    <div>
      <h1>Topic: {decodeURIComponent(name)}</h1>
    </div>
  );
}
