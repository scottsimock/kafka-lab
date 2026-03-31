import Link from 'next/link';
import { getSchemaRegistryUrl } from '@/lib/schema-registry';

interface SchemaVersion {
  version: number;
  id: number;
  schema: string;
  schemaType: string;
}

interface SubjectDetail {
  subject: string;
  compatibility: string;
  versions: SchemaVersion[];
}

async function getSubjectDetail(subject: string): Promise<SubjectDetail> {
  const schemaRegistryUrl = getSchemaRegistryUrl();

  try {
    // Fetch all versions for this subject
    const versionsResponse = await fetch(
      `${schemaRegistryUrl}/subjects/${encodeURIComponent(subject)}/versions`,
      { 
        headers: { 'Accept': 'application/vnd.schemaregistry.v1+json' },
        cache: 'no-store',
      }
    );

    if (!versionsResponse.ok) {
      if (versionsResponse.status === 404) {
        throw new Error('Subject not found');
      }
      throw new Error('Failed to fetch subject versions');
    }

    const versionNumbers: number[] = await versionsResponse.json();

    // Fetch schema details for each version
    const versions = await Promise.all(
      versionNumbers.map(async (version): Promise<SchemaVersion> => {
        try {
          const schemaResponse = await fetch(
            `${schemaRegistryUrl}/subjects/${encodeURIComponent(subject)}/versions/${version}`,
            { 
              headers: { 'Accept': 'application/vnd.schemaregistry.v1+json' },
              cache: 'no-store',
            }
          );

          if (!schemaResponse.ok) {
            return {
              version,
              id: 0,
              schema: 'Error fetching schema',
              schemaType: 'unknown',
            };
          }

          const schemaData = await schemaResponse.json();
          return {
            version,
            id: schemaData.id || 0,
            schema: schemaData.schema || '',
            schemaType: schemaData.schemaType || 'AVRO',
          };
        } catch {
          return {
            version,
            id: 0,
            schema: 'Error fetching schema',
            schemaType: 'unknown',
          };
        }
      })
    );

    // Fetch compatibility config
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
      subject,
      compatibility,
      versions: versions.sort((a, b) => b.version - a.version), // Sort descending
    };
  } catch (error) {
    console.error('Schema Registry error:', error);
    throw error;
  }
}

export default async function SubjectDetailPage({
  params,
}: {
  params: Promise<{ subject: string }>;
}) {
  const { subject } = await params;
  let subjectDetail: SubjectDetail | null = null;
  let error: string | null = null;

  try {
    subjectDetail = await getSubjectDetail(subject);
  } catch (err) {
    error = err instanceof Error ? err.message : 'Failed to fetch subject detail';
  }

  if (error) {
    return (
      <div className="p-6">
        <div className="mb-4">
          <Link
            href="/dashboard/schemas"
            className="text-blue-600 hover:text-blue-800 hover:underline"
          >
            ← Back to Schemas
          </Link>
        </div>
        <h1 className="text-2xl font-bold mb-4">Schema Subject: {subject}</h1>
        <div className="bg-red-50 border border-red-200 rounded-lg p-4">
          <p className="text-red-800">{error}</p>
        </div>
      </div>
    );
  }

  if (!subjectDetail) {
    return (
      <div className="p-6">
        <div className="mb-4">
          <Link
            href="/dashboard/schemas"
            className="text-blue-600 hover:text-blue-800 hover:underline"
          >
            ← Back to Schemas
          </Link>
        </div>
        <h1 className="text-2xl font-bold mb-4">Schema Subject: {subject}</h1>
        <p className="text-gray-500">Subject not found.</p>
      </div>
    );
  }

  return (
    <div className="p-6">
      <div className="mb-4">
        <Link
          href="/dashboard/schemas"
          className="text-blue-600 hover:text-blue-800 hover:underline"
        >
          ← Back to Schemas
        </Link>
      </div>
      
      <h1 className="text-2xl font-bold mb-2">{subjectDetail.subject}</h1>
      <div className="mb-6">
        <span className="text-sm text-gray-600">
          Compatibility: <span className="font-medium">{subjectDetail.compatibility}</span>
        </span>
      </div>

      <div className="space-y-6">
        {subjectDetail.versions.map((version) => (
          <div key={version.version} className="bg-white rounded-lg shadow p-6">
            <div className="mb-4">
              <h2 className="text-xl font-semibold mb-2">
                Version {version.version}
              </h2>
              <div className="text-sm text-gray-600 space-y-1">
                <p>Schema ID: {version.id}</p>
                <p>Schema Type: {version.schemaType}</p>
              </div>
            </div>
            
            <div className="bg-gray-50 rounded p-4 overflow-x-auto">
              <pre className="text-sm">
                <code>{formatSchema(version.schema, version.schemaType)}</code>
              </pre>
            </div>
          </div>
        ))}
      </div>
    </div>
  );
}

// Helper function to format schema for display
function formatSchema(schema: string, schemaType: string): string {
  if (schemaType === 'AVRO' || schemaType === 'JSON') {
    try {
      return JSON.stringify(JSON.parse(schema), null, 2);
    } catch {
      return schema;
    }
  }
  return schema;
}
