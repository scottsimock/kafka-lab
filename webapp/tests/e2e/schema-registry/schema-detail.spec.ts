import { test, expect, VALID_COMPATIBILITY_LEVELS } from './schema-registry.fixture';

test.describe('Schema detail — version and content verification', () => {
  /**
   * Navigate to listing first, then click into the first subject.
   * If no subjects exist, detail tests are skipped.
   */
  let subjectUrl: string | null = null;
  let subjectName: string | null = null;

  test.beforeEach(async ({ page }) => {
    await page.goto('/dashboard/schemas');
    await page.waitForLoadState('networkidle');

    const table = page.locator('table');
    const hasTable = await table.isVisible().catch(() => false);
    if (!hasTable) {
      subjectUrl = null;
      subjectName = null;
      return;
    }

    const rows = table.locator('tbody tr');
    const rowCount = await rows.count();
    if (rowCount === 0) {
      subjectUrl = null;
      subjectName = null;
      return;
    }

    const firstLink = rows.first().locator('a');
    subjectUrl = await firstLink.getAttribute('href');
    subjectName = (await firstLink.textContent())?.trim() ?? null;

    if (subjectUrl) {
      await page.goto(subjectUrl);
      await page.waitForLoadState('networkidle');
    }
  });

  test('detail page shows subject name as heading', async ({ page }) => {
    test.skip(!subjectUrl, 'No schema subjects available — skipping detail test');

    const heading = page.locator('h1');
    await expect(heading).toContainText(subjectName!);
  });

  test('detail page displays compatibility level', async ({ page }) => {
    test.skip(!subjectUrl, 'No schema subjects available');

    const compatLabel = page.locator('text=Compatibility:');
    await expect(compatLabel).toBeVisible();

    // The compatibility value sits in a sibling span
    const compatSpan = page.locator('span.font-medium');
    const compatText = (await compatSpan.textContent())?.trim() ?? '';
    expect(VALID_COMPATIBILITY_LEVELS).toContain(compatText);
  });

  test('detail page shows at least one version card', async ({ page }) => {
    test.skip(!subjectUrl, 'No schema subjects available');

    // Each version renders in a card with "Version N" heading
    const versionHeadings = page.locator('h2');
    const count = await versionHeadings.count();
    expect(count).toBeGreaterThan(0);

    // First version heading matches "Version {number}"
    const firstText = await versionHeadings.first().textContent();
    expect(firstText?.trim()).toMatch(/^Version \d+$/);
  });

  test('version card shows Schema ID and Schema Type', async ({ page }) => {
    test.skip(!subjectUrl, 'No schema subjects available');

    const firstCard = page.locator('.rounded-lg.shadow').first();
    await expect(firstCard).toBeVisible();

    // Schema ID line
    const schemaIdText = firstCard.locator('text=Schema ID:');
    await expect(schemaIdText).toBeVisible();

    // Schema Type line
    const schemaTypeText = firstCard.locator('text=Schema Type:');
    await expect(schemaTypeText).toBeVisible();
  });

  test('version card displays schema content in code block', async ({ page }) => {
    test.skip(!subjectUrl, 'No schema subjects available');

    const codeBlock = page.locator('pre code').first();
    await expect(codeBlock).toBeVisible();

    const content = await codeBlock.textContent();
    expect(content?.trim().length).toBeGreaterThan(0);

    // Avro/JSON schemas should contain recognizable structure
    // Don't assert full content — just check it's parseable or non-empty
    expect(content).toBeTruthy();
  });

  test('back link navigates to schema listing', async ({ page }) => {
    test.skip(!subjectUrl, 'No schema subjects available');

    const backLink = page.locator('a', { hasText: 'Back to Schemas' });
    await expect(backLink).toBeVisible();

    const href = await backLink.getAttribute('href');
    expect(href).toBe('/dashboard/schemas');
  });

  test('versions are displayed in descending order', async ({ page }) => {
    test.skip(!subjectUrl, 'No schema subjects available');

    const versionHeadings = page.locator('h2');
    const count = await versionHeadings.count();
    if (count < 2) {
      // Single version — ordering not verifiable
      return;
    }

    const versions: number[] = [];
    for (let i = 0; i < count; i++) {
      const text = await versionHeadings.nth(i).textContent();
      const match = text?.trim().match(/^Version (\d+)$/);
      if (match) {
        versions.push(Number(match[1]));
      }
    }

    // Verify descending order
    for (let i = 1; i < versions.length; i++) {
      expect(versions[i]).toBeLessThan(versions[i - 1]);
    }
  });
});
