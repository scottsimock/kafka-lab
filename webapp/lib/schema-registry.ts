export function getSchemaRegistryUrl(): string {
  return process.env.SCHEMA_REGISTRY_URL || 'http://schema-registry:8081';
}
