import { test as base, expect } from '@playwright/test';

/**
 * Shared fixture for Schema Registry integration tests.
 * Uses 60s timeout — Schema Registry queries can be slow
 * on first access through the Function App chain.
 */
export const test = base.extend({});

test.beforeEach(async ({}, testInfo) => {
  testInfo.setTimeout(60_000);
});

/** Simple Avro schema used by compatibility-check and registration tests. */
export const TEST_AVRO_SCHEMA = JSON.stringify({
  type: 'record',
  name: 'TestEvent',
  namespace: 'com.kafkalab.test',
  fields: [
    { name: 'id', type: 'string' },
    { name: 'timestamp', type: 'long' },
  ],
});

/** Known compatibility levels from Confluent Schema Registry. */
export const VALID_COMPATIBILITY_LEVELS = [
  'BACKWARD',
  'BACKWARD_TRANSITIVE',
  'FORWARD',
  'FORWARD_TRANSITIVE',
  'FULL',
  'FULL_TRANSITIVE',
  'NONE',
  'unknown',
];

export { expect };
