import { defineConfig, devices } from '@playwright/test';

/**
 * Playwright E2E configuration for the kafka-lab webapp.
 *
 * Base URL is resolved from the PLAYWRIGHT_BASE_URL env var so tests
 * run against any environment (local dev, Azure dev, staging).
 *
 * Timeouts are set higher than defaults to account for network latency
 * when testing against remote Azure deployments.
 */
export default defineConfig({
  testDir: './tests/e2e',

  /* Fail the build on CI if test.only is left in source code. */
  forbidOnly: !!process.env.CI,

  /* Retry once in CI to handle transient network flakes. */
  retries: process.env.CI ? 1 : 0,

  /* Run tests sequentially in CI for deterministic results. */
  workers: process.env.CI ? 1 : undefined,

  /* Reporter: HTML for CI artifacts, list for local dev. */
  reporter: process.env.CI
    ? [['html', { open: 'never', outputFolder: 'playwright-report' }]]
    : [['list']],

  use: {
    /* Base URL for all page.goto('/') calls. */
    baseURL: process.env.PLAYWRIGHT_BASE_URL ?? 'http://localhost:3000',

    /* Timeouts tuned for remote Azure environments. */
    actionTimeout: 30_000,
    navigationTimeout: 60_000,

    /* Collect trace on first retry for easier debugging. */
    trace: 'on-first-retry',

    /* Capture screenshot on failure. */
    screenshot: 'only-on-failure',
  },

  expect: {
    timeout: 10_000,
  },

  projects: [
    {
      name: 'chromium',
      use: { ...devices['Desktop Chrome'] },
    },
    // Uncomment to enable additional browsers:
    // {
    //   name: 'firefox',
    //   use: { ...devices['Desktop Firefox'] },
    // },
    // {
    //   name: 'webkit',
    //   use: { ...devices['Desktop Safari'] },
    // },
  ],
});
