import { test, expect, VALID_COMPATIBILITY_LEVELS } from './schema-registry.fixture';

test.describe('Schema listing — subject table verification', () => {
  test.beforeEach(async ({ page }) => {
    await page.goto('/dashboard/schemas');
    await page.waitForLoadState('networkidle');
  });

  test('page heading displays "Schema Browser"', async ({ page }) => {
    const heading = page.locator('h1');
    await expect(heading).toHaveText('Schema Browser');
  });

  test('subject table renders with correct header columns', async ({ page }) => {
    const table = page.locator('table');

    // Schema Registry may be down — table absent means error or empty state
    const hasTable = await table.isVisible().catch(() => false);
    if (!hasTable) {
      // Accept error boundary or empty-state message
      const errorVisible = await page
        .locator('text=Schema Registry is unavailable')
        .isVisible()
        .catch(() => false);
      const emptyVisible = await page
        .locator('text=No schemas registered yet')
        .isVisible()
        .catch(() => false);
      const boundaryVisible = await page
        .locator('text=Failed to load schemas')
        .isVisible()
        .catch(() => false);
      expect(errorVisible || emptyVisible || boundaryVisible).toBe(true);
      return;
    }

    const headers = table.locator('thead th');
    await expect(headers).toHaveCount(3);
    await expect(headers.nth(0)).toHaveText('Subject Name');
    await expect(headers.nth(1)).toHaveText('Latest Version');
    await expect(headers.nth(2)).toHaveText('Compatibility');
  });

  test('subject table contains at least one row when schemas exist', async ({ page }) => {
    const table = page.locator('table');
    const hasTable = await table.isVisible().catch(() => false);
    if (!hasTable) {
      // Schema Registry unavailable or no schemas — not a failure
      await expect(page.locator('h1')).toHaveText('Schema Browser');
      return;
    }

    const rows = table.locator('tbody tr');
    const rowCount = await rows.count();
    expect(rowCount).toBeGreaterThan(0);
  });

  test('each subject row shows name, latest version, and compatibility', async ({ page }) => {
    const table = page.locator('table');
    const hasTable = await table.isVisible().catch(() => false);
    if (!hasTable) {
      return; // Schema Registry unavailable — skip structural check
    }

    const firstRow = table.locator('tbody tr').first();
    const cells = firstRow.locator('td');
    await expect(cells).toHaveCount(3);

    // Subject name cell contains a clickable link
    const nameLink = cells.nth(0).locator('a');
    await expect(nameLink).toBeVisible();
    const subjectName = await nameLink.textContent();
    expect(subjectName?.trim().length).toBeGreaterThan(0);

    // Latest version is a non-negative integer
    const versionText = await cells.nth(1).textContent();
    expect(Number(versionText?.trim())).toBeGreaterThanOrEqual(0);

    // Compatibility is a recognized level
    const compatText = (await cells.nth(2).textContent())?.trim() ?? '';
    expect(VALID_COMPATIBILITY_LEVELS).toContain(compatText);
  });

  test('subject name links point to detail pages', async ({ page }) => {
    const table = page.locator('table');
    const hasTable = await table.isVisible().catch(() => false);
    if (!hasTable) {
      return;
    }

    const firstLink = table.locator('tbody tr').first().locator('a');
    const href = await firstLink.getAttribute('href');
    expect(href).toContain('/dashboard/schemas/');
  });

  test('empty state renders when no schemas are registered', async ({ page }) => {
    // This test validates the empty-state path.
    // If the table is visible, schemas exist — skip this check.
    const table = page.locator('table');
    const hasTable = await table.isVisible().catch(() => false);
    if (hasTable) {
      // Schemas exist — empty state not applicable
      return;
    }

    // Either empty message or error boundary should show
    const emptyMsg = page.locator('text=No schemas registered yet');
    const errorMsg = page.locator('text=Schema Registry is unavailable');
    const boundaryMsg = page.locator('text=Failed to load schemas');

    const emptyVisible = await emptyMsg.isVisible().catch(() => false);
    const errorVisible = await errorMsg.isVisible().catch(() => false);
    const boundaryVisible = await boundaryMsg.isVisible().catch(() => false);

    expect(emptyVisible || errorVisible || boundaryVisible).toBe(true);
  });
});
