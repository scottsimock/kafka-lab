import { test as base, expect } from '@playwright/test';

/**
 * Shared fixture for dashboard integration tests.
 * Uses longer timeouts than smoke tests — data loads from live Kafka,
 * which can be slow on first query.
 */
export const test = base.extend({});

test.beforeEach(async ({}, testInfo) => {
  testInfo.setTimeout(60_000);
});

export { expect };
