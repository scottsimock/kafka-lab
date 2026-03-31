import { test as base, expect } from '@playwright/test';

/**
 * Shared fixture for smoke tests. Extends Playwright's base test
 * with a longer default timeout suitable for remote Azure environments.
 */
export const test = base.extend({});

// Remote Azure environments need generous timeouts
test.beforeEach(async ({}, testInfo) => {
  testInfo.setTimeout(30_000);
});

export { expect };
