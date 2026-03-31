import { NextResponse } from 'next/server';
import { getSchemaRegistryUrl } from '@/lib/schema-registry';

export const dynamic = 'force-dynamic';

interface SubjectInfo {
  name: string;
  latestVersion: number;
  compatibility: string;
}

export async function GET() {
  const schemaRegistryUrl = getSchemaRegistryUrl();

  try {
    // Fetch all subjects
    const subjectsResponse = await fetch(`${schemaRegistryUrl}/subjects`, {
      headers: { 'Accept': 'application/vnd.schemaregistry.v1+json' },
    });

    if (!subjectsResponse.ok) {
      return NextResponse.json(
        { error: 'Failed to fetch subjects from Schema Registry' },
        { status: 502 }
      );
    }

    const subjects: string[] = await subjectsResponse.json();

    // Fetch details for each subject
    const subjectDetails = await Promise.all(
      subjects.map(async (subject): Promise<SubjectInfo> => {
        try {
          // Fetch versions for this subject
          const versionsResponse = await fetch(
            `${schemaRegistryUrl}/subjects/${encodeURIComponent(subject)}/versions`,
            { headers: { 'Accept': 'application/vnd.schemaregistry.v1+json' } }
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
              { headers: { 'Accept': 'application/vnd.schemaregistry.v1+json' } }
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

    return NextResponse.json({ subjects: subjectDetails });
  } catch (error) {
    console.error('Schema Registry error:', error);
    return NextResponse.json(
      { error: 'Schema Registry is unavailable' },
      { status: 502 }
    );
  }
}
