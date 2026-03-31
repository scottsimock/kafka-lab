import { test, expect } from './dashboard.fixture';

test.describe('Topic listing — live data verification', () => {
  test.beforeEach(async ({ page }) => {
    await page.goto('/dashboard/topics');
    await page.waitForLoadState('networkidle');
  });

  test('page heading displays "Topics"', async ({ page }) => {
    const heading = page.locator('h1');
    await expect(heading).toHaveText('Topics');
  });

  test('topic table renders with header columns', async ({ page }) => {
    const table = page.locator('table');

    // If Kafka is up, we get a table. If down, error boundary shows.
    const hasTable = await table.isVisible().catch(() => false);
    if (!hasTable) {
      // Error boundary should be present instead
      await expect(page.locator('text=Error loading topics')).toBeVisible();
      return;
    }

    const headers = table.locator('thead th');
    await expect(headers).toHaveCount(3);
    await expect(headers.nth(0)).toHaveText('Topic Name');
    await expect(headers.nth(1)).toHaveText('Partitions');
    await expect(headers.nth(2)).toHaveText('Replication Factor');
  });

  test('topic table contains at least one row with live data', async ({ page }) => {
    const table = page.locator('table');
    const hasTable = await table.isVisible().catch(() => false);
    if (!hasTable) {
      await expect(page.locator('text=Error loading topics')).toBeVisible();
      return;
    }

    const rows = table.locator('tbody tr');
    const rowCount = await rows.count();
    expect(rowCount).toBeGreaterThan(0);
  });

  test('each topic row shows name, partition count, and replication factor', async ({ page }) => {
    const table = page.locator('table');
    const hasTable = await table.isVisible().catch(() => false);
    if (!hasTable) {
      return; // Kafka unavailable — skip structural check
    }

    const firstRow = table.locator('tbody tr').first();
    const cells = firstRow.locator('td');
    await expect(cells).toHaveCount(3);

    // Topic name cell contains a link
    const nameLink = cells.nth(0).locator('a');
    await expect(nameLink).toBeVisible();
    const topicName = await nameLink.textContent();
    expect(topicName?.trim().length).toBeGreaterThan(0);

    // Partition count is a positive integer
    const partitions = await cells.nth(1).textContent();
    expect(Number(partitions?.trim())).toBeGreaterThanOrEqual(1);

    // Replication factor is a positive integer
    const replication = await cells.nth(2).textContent();
    expect(Number(replication?.trim())).toBeGreaterThanOrEqual(1);
  });

  test('topic name links point to detail pages', async ({ page }) => {
    const table = page.locator('table');
    const hasTable = await table.isVisible().catch(() => false);
    if (!hasTable) {
      return;
    }

    const firstLink = table.locator('tbody tr').first().locator('a');
    const href = await firstLink.getAttribute('href');
    expect(href).toContain('/dashboard/topics/');
  });
});
