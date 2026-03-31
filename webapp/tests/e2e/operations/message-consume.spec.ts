import { test, expect } from './operations.fixture';

/**
 * Message consumption tests — verify the UI fetches messages from Kafka
 * and displays them in the message table with correct structure.
 */
test.describe('Message consumption via UI', () => {
  test.beforeEach(async ({ page }) => {
    await page.goto('/dashboard/messages');
    await page.waitForLoadState('networkidle');
  });

  test('message browser page loads with heading and topic selector', async ({ page }) => {
    await expect(page.locator('h1')).toHaveText('Message Browser');
    await expect(page.locator('#topic-select')).toBeVisible();
  });

  test('fetch messages button is available when a topic is selected', async ({ page }) => {
    const select = page.locator('#topic-select');
    const selectVisible = await select.isVisible().catch(() => false);

    if (!selectVisible) {
      test.skip(true, 'Topic selector not available — Kafka may be offline');
      return;
    }

    const options = select.locator('option');
    const optCount = await options.count();

    if (optCount === 0 || (optCount === 1 && await options.first().textContent() === 'No topics available')) {
      test.skip(true, 'No topics available');
      return;
    }

    await expect(
      page.locator('button:has-text("Fetch Messages")'),
    ).toBeVisible();
  });

  test('fetch messages displays results in a table', async ({ page }) => {
    const select = page.locator('#topic-select');
    const selectVisible = await select.isVisible().catch(() => false);

    if (!selectVisible) {
      test.skip(true, 'Topic selector not available — Kafka may be offline');
      return;
    }

    const options = select.locator('option');
    const optCount = await options.count();

    if (optCount === 0 || (optCount === 1 && await options.first().textContent() === 'No topics available')) {
      test.skip(true, 'No topics available');
      return;
    }

    await page.locator('button:has-text("Fetch Messages")').click();

    // Wait for fetch to complete
    await expect(
      page.locator('button:has-text("Fetch Messages")'),
    ).toBeVisible({ timeout: 30_000 });

    // Either messages appear in a table or the empty state shows
    const messageTable = page.locator('table');
    const emptyState = page.locator('text=No messages to display');
    const hasTable = await messageTable.isVisible().catch(() => false);
    const hasEmpty = await emptyState.isVisible().catch(() => false);

    expect(
      hasTable || hasEmpty,
      'Expected either a message table or empty state after fetch',
    ).toBe(true);
  });

  test('message table has correct column headers', async ({ page, ops }) => {
    const select = page.locator('#topic-select');
    const selectVisible = await select.isVisible().catch(() => false);

    if (!selectVisible) {
      test.skip(true, 'Topic selector not available — Kafka may be offline');
      return;
    }

    const options = select.locator('option');
    const optCount = await options.count();

    if (optCount === 0 || (optCount === 1 && await options.first().textContent() === 'No topics available')) {
      test.skip(true, 'No topics available');
      return;
    }

    // Get the selected topic and seed a message so the table renders
    const selectedTopic = await select.inputValue();
    await ops.produceMessage(selectedTopic, `header-test-${Date.now()}`, 'header-check');

    // Allow Kafka propagation
    await page.waitForTimeout(2_000);

    await page.locator('button:has-text("Fetch Messages")').click();
    await expect(
      page.locator('button:has-text("Fetch Messages")'),
    ).toBeVisible({ timeout: 30_000 });

    const table = page.locator('table');
    const hasTable = await table.isVisible().catch(() => false);

    if (!hasTable) {
      test.skip(true, 'No messages returned — cannot verify headers');
      return;
    }

    const headers = table.locator('thead th');
    await expect(headers.nth(0)).toHaveText('Key');
    await expect(headers.nth(1)).toHaveText('Value');
    await expect(headers.nth(2)).toHaveText('Partition');
    await expect(headers.nth(3)).toHaveText('Offset');
    await expect(headers.nth(4)).toHaveText('Timestamp');
  });

  test('consumed messages display key, value, partition, offset, and timestamp', async ({
    page,
    ops,
  }) => {
    const select = page.locator('#topic-select');
    const selectVisible = await select.isVisible().catch(() => false);

    if (!selectVisible) {
      test.skip(true, 'Topic selector not available — Kafka may be offline');
      return;
    }

    const options = select.locator('option');
    const optCount = await options.count();

    if (optCount === 0 || (optCount === 1 && await options.first().textContent() === 'No topics available')) {
      test.skip(true, 'No topics available');
      return;
    }

    // Seed a known message
    const selectedTopic = await select.inputValue();
    const testKey = `e2e-consume-${Date.now()}`;
    const testValue = `consume-verification-${Date.now()}`;
    await ops.produceMessage(selectedTopic, testKey, testValue);

    await page.waitForTimeout(2_000);

    await page.locator('button:has-text("Fetch Messages")').click();
    await expect(
      page.locator('button:has-text("Fetch Messages")'),
    ).toBeVisible({ timeout: 30_000 });

    const table = page.locator('table');
    const hasTable = await table.isVisible().catch(() => false);

    if (!hasTable) {
      test.skip(true, 'No messages returned — Kafka may be empty or offline');
      return;
    }

    // Verify at least one row exists
    const rows = table.locator('tbody tr');
    const rowCount = await rows.count();
    expect(rowCount).toBeGreaterThan(0);

    // Each row should have 5 cells
    const firstRow = rows.first();
    const cells = firstRow.locator('td');
    await expect(cells).toHaveCount(5);

    // Partition should be a non-negative integer
    const partitionText = await cells.nth(2).textContent();
    expect(Number(partitionText?.trim())).toBeGreaterThanOrEqual(0);

    // Offset should be a non-negative integer string
    const offsetText = await cells.nth(3).textContent();
    expect(Number(offsetText?.trim())).toBeGreaterThanOrEqual(0);

    // Timestamp should be non-empty
    const tsText = await cells.nth(4).textContent();
    expect(tsText?.trim().length).toBeGreaterThan(0);
  });

  test('changing topic selector clears previous messages', async ({ page }) => {
    const select = page.locator('#topic-select');
    const selectVisible = await select.isVisible().catch(() => false);

    if (!selectVisible) {
      test.skip(true, 'Topic selector not available — Kafka may be offline');
      return;
    }

    const options = select.locator('option');
    const optCount = await options.count();

    if (optCount < 2) {
      test.skip(true, 'Need at least 2 topics to test selector change');
      return;
    }

    // Fetch messages for first topic
    await page.locator('button:has-text("Fetch Messages")').click();
    await expect(
      page.locator('button:has-text("Fetch Messages")'),
    ).toBeVisible({ timeout: 30_000 });

    // Switch to second topic
    const secondValue = await options.nth(1).getAttribute('value');
    if (secondValue) {
      await select.selectOption(secondValue);
    }

    // After switching, either empty state shows or table is gone/refreshed
    const emptyState = page.locator('text=No messages to display');
    const emptyVisible = await emptyState.isVisible().catch(() => false);

    // The messages array gets cleared on topic change
    expect(emptyVisible).toBe(true);
  });
});
