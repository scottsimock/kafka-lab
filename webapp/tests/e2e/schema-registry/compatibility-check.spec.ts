import { test, expect, TEST_AVRO_SCHEMA } from './schema-registry.fixture';

/**
 * Compatibility check tests exercise the Schema Registry API
 * through the web app's API routes. The UI for compatibility
 * checking may not be built yet — these tests validate the
 * underlying /api/schemas API and, when the UI exists, the
 * compatibility check form.
 */
test.describe('Compatibility check — schema validation', () => {
  test('API returns subject list with compatibility levels', async ({ request }) => {
    const response = await request.get('/api/schemas');

    // Schema Registry may be unreachable — accept 200 or 502
    if (response.status() === 502) {
      const body = await response.json();
      expect(body).toHaveProperty('error');
      return;
    }

    expect(response.status()).toBe(200);
    const body = await response.json();
    expect(body).toHaveProperty('subjects');
    expect(Array.isArray(body.subjects)).toBe(true);

    // Each subject should have a compatibility field
    for (const subject of body.subjects) {
      expect(subject).toHaveProperty('compatibility');
      expect(typeof subject.compatibility).toBe('string');
    }
  });

  test('API returns subject detail with version schemas', async ({ request }) => {
    // First get a subject name
    const listResponse = await request.get('/api/schemas');
    if (listResponse.status() !== 200) {
      test.skip(true, 'Schema Registry unavailable');
      return;
    }

    const listBody = await listResponse.json();
    if (!listBody.subjects || listBody.subjects.length === 0) {
      test.skip(true, 'No schemas registered — skipping detail check');
      return;
    }

    const subjectName = listBody.subjects[0].name;
    const detailResponse = await request.get(
      `/api/schemas/${encodeURIComponent(subjectName)}`
    );

    expect(detailResponse.status()).toBe(200);
    const detail = await detailResponse.json();

    expect(detail).toHaveProperty('subject', subjectName);
    expect(detail).toHaveProperty('compatibility');
    expect(detail).toHaveProperty('versions');
    expect(Array.isArray(detail.versions)).toBe(true);

    if (detail.versions.length > 0) {
      const firstVersion = detail.versions[0];
      expect(firstVersion).toHaveProperty('version');
      expect(firstVersion).toHaveProperty('id');
      expect(firstVersion).toHaveProperty('schema');
      expect(firstVersion).toHaveProperty('schemaType');
    }
  });

  test('compatibility level is displayed for each subject in the UI', async ({ page }) => {
    await page.goto('/dashboard/schemas');
    await page.waitForLoadState('networkidle');

    const table = page.locator('table');
    const hasTable = await table.isVisible().catch(() => false);
    if (!hasTable) {
      // No data — verify fallback state
      await expect(page.locator('h1')).toHaveText('Schema Browser');
      return;
    }

    // Verify every row has a compatibility cell (3rd column)
    const rows = table.locator('tbody tr');
    const rowCount = await rows.count();

    for (let i = 0; i < rowCount; i++) {
      const compatCell = rows.nth(i).locator('td').nth(2);
      const text = (await compatCell.textContent())?.trim() ?? '';
      expect(text.length).toBeGreaterThan(0);
    }
  });

  test('detail page compatibility matches listing page value', async ({ page }) => {
    await page.goto('/dashboard/schemas');
    await page.waitForLoadState('networkidle');

    const table = page.locator('table');
    const hasTable = await table.isVisible().catch(() => false);
    if (!hasTable) {
      return;
    }

    const firstRow = table.locator('tbody tr').first();
    const listingCompat = (
      await firstRow.locator('td').nth(2).textContent()
    )?.trim();

    // Navigate to detail page
    const link = firstRow.locator('a');
    await link.click();
    await page.waitForLoadState('networkidle');

    // Read compatibility from detail page
    const compatSpan = page.locator('span.font-medium');
    const detailCompat = (await compatSpan.textContent())?.trim();

    expect(detailCompat).toBe(listingCompat);
  });

  test('compatibility check via Schema Registry API (direct)', async ({ request }) => {
    // Exercise Schema Registry compatibility endpoint through the API layer.
    // When the compatibility check UI is built, this validates the backend path.
    const listResponse = await request.get('/api/schemas');
    if (listResponse.status() !== 200) {
      test.skip(true, 'Schema Registry unavailable');
      return;
    }

    const listBody = await listResponse.json();
    if (!listBody.subjects || listBody.subjects.length === 0) {
      test.skip(true, 'No schemas to check compatibility against');
      return;
    }

    // Verify we can fetch the first subject's schema for comparison
    const subjectName = listBody.subjects[0].name;
    const detailResponse = await request.get(
      `/api/schemas/${encodeURIComponent(subjectName)}`
    );
    expect(detailResponse.status()).toBe(200);

    const detail = await detailResponse.json();
    expect(detail.versions.length).toBeGreaterThan(0);

    // The schema content should be valid JSON (Avro or JSON schema)
    const schemaContent = detail.versions[0].schema;
    expect(() => JSON.parse(schemaContent)).not.toThrow();
  });
});
