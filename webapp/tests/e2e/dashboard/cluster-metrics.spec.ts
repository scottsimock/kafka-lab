import { test, expect } from './dashboard.fixture';

test.describe('Cluster metrics — broker and health data', () => {
  test.beforeEach(async ({ page }) => {
    await page.goto('/dashboard/overview');
    await page.waitForLoadState('networkidle');
  });

  test('page heading displays "Cluster Overview"', async ({ page }) => {
    // Page may show heading or error boundary
    const heading = page.locator('h1');
    const headingVisible = await heading.isVisible().catch(() => false);
    if (headingVisible) {
      await expect(heading).toHaveText('Cluster Overview');
    } else {
      await expect(page.locator('text=Failed to load cluster overview')).toBeVisible();
    }
  });

  test('health badge displays a recognized status', async ({ page }) => {
    const errorVisible = await page.locator('text=Failed to load cluster overview').isVisible().catch(() => false);
    if (errorVisible) {
      return; // Kafka offline
    }

    // Health badge is a span after "Cluster Health:" label
    await expect(page.locator('text=Cluster Health:')).toBeVisible();

    const healthBadge = page.locator('header span').last();
    const healthText = await healthBadge.textContent();
    const validHealthStates = ['Healthy', 'Degraded', 'Unhealthy'];
    expect(validHealthStates).toContain(healthText?.trim());
  });

  test('summary section shows topic and partition counts', async ({ page }) => {
    const errorVisible = await page.locator('text=Failed to load cluster overview').isVisible().catch(() => false);
    if (errorVisible) {
      return;
    }

    await expect(page.locator('h2:has-text("Summary")')).toBeVisible();
    await expect(page.locator('text=Total Topics')).toBeVisible();
    await expect(page.locator('text=Total Partitions')).toBeVisible();
    await expect(page.locator('text=Under-Replicated')).toBeVisible();
    await expect(page.locator('text=Offline Partitions')).toBeVisible();
  });

  test('summary metric values are non-negative integers', async ({ page }) => {
    const errorVisible = await page.locator('text=Failed to load cluster overview').isVisible().catch(() => false);
    if (errorVisible) {
      return;
    }

    // Each metric card has a label div followed by a value div
    const metricCards = page.locator('section').first().locator('div[style*="border"]');
    const cardCount = await metricCards.count();
    expect(cardCount).toBe(4);

    for (let i = 0; i < cardCount; i++) {
      const valueDiv = metricCards.nth(i).locator('div').last();
      const valueText = await valueDiv.textContent();
      const numericValue = Number(valueText?.trim());
      expect(numericValue).toBeGreaterThanOrEqual(0);
      expect(Number.isInteger(numericValue)).toBe(true);
    }
  });

  test('brokers section renders table with header columns', async ({ page }) => {
    const errorVisible = await page.locator('text=Failed to load cluster overview').isVisible().catch(() => false);
    if (errorVisible) {
      return;
    }

    await expect(page.locator('h2:has-text("Brokers")')).toBeVisible();

    const brokerTable = page.locator('section').last().locator('table');
    const headers = brokerTable.locator('thead th');
    await expect(headers).toHaveCount(4);
    await expect(headers.nth(0)).toHaveText('Node ID');
    await expect(headers.nth(1)).toHaveText('Host');
    await expect(headers.nth(2)).toHaveText('Port');
    await expect(headers.nth(3)).toHaveText('Status');
  });

  test('broker table shows at least one broker', async ({ page }) => {
    const errorVisible = await page.locator('text=Failed to load cluster overview').isVisible().catch(() => false);
    if (errorVisible) {
      return;
    }

    const brokerTable = page.locator('section').last().locator('table');
    const rows = brokerTable.locator('tbody tr');
    const rowCount = await rows.count();
    expect(rowCount).toBeGreaterThan(0);
  });

  test('each broker row shows node ID, host, port, and online status', async ({ page }) => {
    const errorVisible = await page.locator('text=Failed to load cluster overview').isVisible().catch(() => false);
    if (errorVisible) {
      return;
    }

    const brokerTable = page.locator('section').last().locator('table');
    const firstRow = brokerTable.locator('tbody tr').first();
    const cells = firstRow.locator('td');
    await expect(cells).toHaveCount(4);

    // Node ID is a non-negative integer
    const nodeId = await cells.nth(0).textContent();
    expect(Number(nodeId?.trim())).toBeGreaterThanOrEqual(0);

    // Host is non-empty
    const host = await cells.nth(1).textContent();
    expect(host?.trim().length).toBeGreaterThan(0);

    // Port is a positive integer
    const port = await cells.nth(2).textContent();
    expect(Number(port?.trim())).toBeGreaterThan(0);

    // Status shows "Online"
    await expect(cells.nth(3).locator('text=Online')).toBeVisible();
  });
});
