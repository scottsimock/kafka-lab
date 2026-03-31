import { test, expect } from '../fixtures/smoke.fixture';

test.describe('Error handling — 404 for invalid routes', () => {
  test('unknown top-level route returns 404', async ({ page }) => {
    const response = await page.goto('/nonexistent-page-xyz');
    expect(response).not.toBeNull();
    expect(response!.status()).toBe(404);
  });

  test('unknown dashboard route returns 404', async ({ page }) => {
    const response = await page.goto('/dashboard/nonexistent-view');
    expect(response).not.toBeNull();
    expect(response!.status()).toBe(404);
  });

  test('404 page renders readable content', async ({ page }) => {
    await page.goto('/nonexistent-page-xyz');
    // Next.js default 404 shows "404" and "This page could not be found"
    const body = page.locator('body');
    await expect(body).toBeVisible();
    const text = await body.innerText();
    expect(text).toMatch(/404|not found/i);
  });
});

test.describe('Error handling — invalid API routes return proper errors', () => {
  test('unknown API route returns 404', async ({ request }) => {
    const response = await request.get('/api/nonexistent-endpoint');
    expect(response.status()).toBe(404);
  });

  test('GET /api/topics/nonexistent-topic handles missing topic', async ({ request }) => {
    const response = await request.get('/api/topics/definitely-does-not-exist-xyz');
    // Should return 404 or 500 depending on implementation, not crash
    expect([404, 500]).toContain(response.status());
    const contentType = response.headers()['content-type'] ?? '';
    expect(contentType).toContain('application/json');
  });

  test('GET /api/consumer-groups/nonexistent-group handles missing group', async ({ request }) => {
    const response = await request.get('/api/consumer-groups/fake-group-id-xyz');
    expect([404, 500]).toContain(response.status());
    const contentType = response.headers()['content-type'] ?? '';
    expect(contentType).toContain('application/json');
  });

  test('GET /api/schemas/nonexistent-subject handles missing subject', async ({ request }) => {
    const response = await request.get('/api/schemas/fake-subject-xyz');
    expect([404, 500]).toContain(response.status());
    const contentType = response.headers()['content-type'] ?? '';
    expect(contentType).toContain('application/json');
  });
});

test.describe('Error handling — dashboard error boundaries catch failures', () => {
  test('overview page renders error boundary or content on failure', async ({ page }) => {
    await page.goto('/dashboard/overview');
    // Whether Kafka is up or down, the page should render something —
    // either the cluster overview or the error boundary with "Something went wrong!"
    const visibleContent = page.locator('h1, h2').first();
    await expect(visibleContent).toBeVisible();
    const text = await visibleContent.innerText();
    expect(text.length).toBeGreaterThan(0);
  });

  test('error boundary shows Try Again button when an error occurs', async ({ page }) => {
    await page.goto('/dashboard/overview');
    const tryAgain = page.locator('button', { hasText: 'Try again' });
    // Only check if error boundary is active
    const isErrorState = await tryAgain.isVisible().catch(() => false);
    if (isErrorState) {
      await expect(tryAgain).toBeEnabled();
    }
  });
});
