import { NextResponse } from 'next/server';
import { getSchemaRegistryUrl } from '@/lib/schema-registry';

export const dynamic = 'force-dynamic';

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

export async function GET(
  request: Request,
  { params }: { params: Promise<{ subject: string }> }
) {
  const { subject } = await params;
  const schemaRegistryUrl = getSchemaRegistryUrl();

  try {
    // Fetch all versions for this subject
    const versionsResponse = await fetch(
      `${schemaRegistryUrl}/subjects/${encodeURIComponent(subject)}/versions`,
      { headers: { 'Accept': 'application/vnd.schemaregistry.v1+json' } }
    );

    if (!versionsResponse.ok) {
      if (versionsResponse.status === 404) {
        return NextResponse.json(
          { error: 'Subject not found' },
          { status: 404 }
        );
      }
      return NextResponse.json(
        { error: 'Failed to fetch subject versions' },
        { status: 502 }
      );
    }

    const versionNumbers: number[] = await versionsResponse.json();

    // Fetch schema details for each version
    const versions = await Promise.all(
      versionNumbers.map(async (version): Promise<SchemaVersion> => {
        try {
          const schemaResponse = await fetch(
            `${schemaRegistryUrl}/subjects/${encodeURIComponent(subject)}/versions/${version}`,
            { headers: { 'Accept': 'application/vnd.schemaregistry.v1+json' } }
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
        { headers: { 'Accept': 'application/vnd.schemaregistry.v1+json' } }
      );
      if (configResponse.ok) {
        const config = await configResponse.json();
        compatibility = config.compatibilityLevel || compatibility;
      }
    } catch {
      // Use default if config fetch fails
    }

    const result: SubjectDetail = {
      subject,
      compatibility,
      versions: versions.sort((a, b) => b.version - a.version), // Sort descending
    };

    return NextResponse.json(result);
  } catch (error) {
    console.error('Schema Registry error:', error);
    return NextResponse.json(
      { error: 'Schema Registry is unavailable' },
      { status: 502 }
    );
  }
}
