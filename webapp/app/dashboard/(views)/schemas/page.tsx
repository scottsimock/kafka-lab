import Link from 'next/link';
import { getSchemaRegistryUrl } from '@/lib/schema-registry';

interface SubjectInfo {
  name: string;
  latestVersion: number;
  compatibility: string;
}

async function getSchemas(): Promise<SubjectInfo[]> {
  const schemaRegistryUrl = getSchemaRegistryUrl();

  try {
    // Fetch all subjects directly from Schema Registry
    const subjectsResponse = await fetch(`${schemaRegistryUrl}/subjects`, {
      headers: { 'Accept': 'application/vnd.schemaregistry.v1+json' },
      cache: 'no-store',
    });

    if (!subjectsResponse.ok) {
      throw new Error('Failed to fetch subjects from Schema Registry');
    }

    const subjects: string[] = await subjectsResponse.json();

    // Fetch details for each subject
    const subjectDetails = await Promise.all(
      subjects.map(async (subject): Promise<SubjectInfo> => {
        try {
          // Fetch versions for this subject
          const versionsResponse = await fetch(
            `${schemaRegistryUrl}/subjects/${encodeURIComponent(subject)}/versions`,
            { 
              headers: { 'Accept': 'application/vnd.schemaregistry.v1+json' },
              cache: 'no-store',
            }
          );

          if (!versionsResponse.ok) {
            return {
              name: subject,
              latestVersion: 0,
              compatibility: 'unknown',
            };
          }

          const versions: number[] = await versionsResponse.json();
          const latestVersion = versions.length > 0 ? Math.max(...versions) : 0;

          // Fetch compatibility config for this subject
          let compatibility = 'BACKWARD'; // Default
          try {
            const configResponse = await fetch(
              `${schemaRegistryUrl}/config/${encodeURIComponent(subject)}`,
              { 
                headers: { 'Accept': 'application/vnd.schemaregistry.v1+json' },
                cache: 'no-store',
              }
            );
            if (configResponse.ok) {
              const config = await configResponse.json();
              compatibility = config.compatibilityLevel || compatibility;
            }
          } catch {
            // Use default if config fetch fails
          }

          return {
            name: subject,
            latestVersion,
            compatibility,
          };
        } catch {
          return {
            name: subject,
            latestVersion: 0,
            compatibility: 'unknown',
          };
        }
      })
    );

    return subjectDetails;
  } catch (error) {
    console.error('Schema Registry error:', error);
    throw error;
  }
}

export default async function SchemasPage() {
  let schemas: SubjectInfo[] = [];
  let error: string | null = null;

  try {
    schemas = await getSchemas();
  } catch (err) {
    error = err instanceof Error ? err.message : 'Failed to fetch schemas';
  }

  if (error) {
    return (
      <div className="p-6">
        <h1 className="text-2xl font-bold mb-4">Schema Browser</h1>
        <div className="bg-red-50 border border-red-200 rounded-lg p-4">
          <p className="text-red-800">
            Schema Registry is unavailable: {error}
          </p>
        </div>
      </div>
    );
  }

  if (schemas.length === 0) {
    return (
      <div className="p-6">
        <h1 className="text-2xl font-bold mb-4">Schema Browser</h1>
        <p className="text-gray-500">No schemas registered yet.</p>
      </div>
    );
  }

  return (
    <div className="p-6">
      <h1 className="text-2xl font-bold mb-4">Schema Browser</h1>
      <div className="bg-white rounded-lg shadow overflow-hidden">
        <table className="min-w-full divide-y divide-gray-200">
          <thead className="bg-gray-50">
            <tr>
              <th className="px-6 py-3 text-left text-xs font-medium text-gray-500 uppercase tracking-wider">
                Subject Name
              </th>
              <th className="px-6 py-3 text-left text-xs font-medium text-gray-500 uppercase tracking-wider">
                Latest Version
              </th>
              <th className="px-6 py-3 text-left text-xs font-medium text-gray-500 uppercase tracking-wider">
                Compatibility
              </th>
            </tr>
          </thead>
          <tbody className="bg-white divide-y divide-gray-200">
            {schemas.map((schema) => (
              <tr key={schema.name} className="hover:bg-gray-50">
                <td className="px-6 py-4 whitespace-nowrap">
                  <Link
                    href={`/dashboard/schemas/${encodeURIComponent(schema.name)}`}
                    className="text-blue-600 hover:text-blue-800 hover:underline"
                  >
                    {schema.name}
                  </Link>
                </td>
                <td className="px-6 py-4 whitespace-nowrap text-sm text-gray-900">
                  {schema.latestVersion}
                </td>
                <td className="px-6 py-4 whitespace-nowrap text-sm text-gray-900">
                  {schema.compatibility}
                </td>
              </tr>
            ))}
          </tbody>
        </table>
      </div>
    </div>
  );
}

