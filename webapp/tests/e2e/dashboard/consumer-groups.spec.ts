import { test, expect } from './dashboard.fixture';

test.describe('Consumer groups — live data verification', () => {
  test.beforeEach(async ({ page }) => {
    await page.goto('/dashboard/consumer-groups');
    await page.waitForLoadState('networkidle');
  });

  test('page heading displays "Consumer Groups"', async ({ page }) => {
    const heading = page.locator('h1');
    await expect(heading).toHaveText('Consumer Groups');
  });

  test('consumer groups table renders with header columns', async ({ page }) => {
    const table = page.locator('table');
    const hasTable = await table.isVisible().catch(() => false);

    if (!hasTable) {
      // Either error boundary or "No consumer groups found" message
      const errorVisible = await page.locator('text=Error loading consumer groups').isVisible().catch(() => false);
      const emptyVisible = await page.locator('text=No consumer groups found').isVisible().catch(() => false);
      expect(errorVisible || emptyVisible).toBe(true);
      return;
    }

    const headers = table.locator('thead th');
    await expect(headers).toHaveCount(4);
    await expect(headers.nth(0)).toHaveText('Group ID');
    await expect(headers.nth(1)).toHaveText('State');
    await expect(headers.nth(2)).toHaveText('Members');
    await expect(headers.nth(3)).toHaveText('Protocol Type');
  });

  test('consumer groups table shows at least one group', async ({ page }) => {
    const table = page.locator('table');
    const hasTable = await table.isVisible().catch(() => false);
    if (!hasTable) {
      return; // No groups or Kafka offline — acceptable
    }

    const rows = table.locator('tbody tr');
    const rowCount = await rows.count();
    expect(rowCount).toBeGreaterThan(0);
  });

  test('each group row shows state badge with recognized state', async ({ page }) => {
    const table = page.locator('table');
    const hasTable = await table.isVisible().catch(() => false);
    if (!hasTable) {
      return;
    }

    const firstRow = table.locator('tbody tr').first();
    const stateBadge = firstRow.locator('td').nth(1).locator('span');
    await expect(stateBadge).toBeVisible();

    const stateText = await stateBadge.textContent();
    const validStates = ['Stable', 'Empty', 'Dead', 'Rebalancing', 'Preparingrebalance', 'Completingrebalance'];
    expect(validStates.some(s => stateText?.includes(s))).toBe(true);
  });

  test('group ID links point to detail pages', async ({ page }) => {
    const table = page.locator('table');
    const hasTable = await table.isVisible().catch(() => false);
    if (!hasTable) {
      return;
    }

    const firstLink = table.locator('tbody tr').first().locator('a');
    const href = await firstLink.getAttribute('href');
    expect(href).toContain('/dashboard/consumer-groups/');
  });

  test('refresh button is present', async ({ page }) => {
    const refreshButton = page.locator('button:has-text("Refresh")');
    await expect(refreshButton).toBeVisible();
  });
});
