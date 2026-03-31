export default async function ConsumerGroupDetailPage({
  params,
}: {
  params: Promise<{ id: string }>;
}) {
  const { id } = await params;
  
  return (
    <div>
      <h1>Consumer Group: {id}</h1>
    </div>
  );
}
