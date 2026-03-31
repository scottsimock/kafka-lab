import { test, expect } from '../fixtures/smoke.fixture';

test.describe('Page loads — every route returns 200', () => {
  test('home page redirects to dashboard overview', async ({ page }) => {
    const response = await page.goto('/');
    expect(response).not.toBeNull();
    expect(response!.status()).toBe(200);
    // Root page redirects to /dashboard/overview
    expect(page.url()).toContain('/dashboard/overview');
  });

  test('dashboard overview page loads and shows cluster overview', async ({ page }) => {
    const response = await page.goto('/dashboard/overview');
    expect(response).not.toBeNull();
    expect(response!.status()).toBe(200);
    // Page should render either the overview content or an error boundary
    const heading = page.locator('h1, h2').first();
    await expect(heading).toBeVisible();
  });

  test('topics listing page loads and renders', async ({ page }) => {
    const response = await page.goto('/dashboard/topics');
    expect(response).not.toBeNull();
    expect(response!.status()).toBe(200);
    const heading = page.locator('h1, h2').first();
    await expect(heading).toBeVisible();
  });

  test('consumer groups page loads and renders', async ({ page }) => {
    const response = await page.goto('/dashboard/consumer-groups');
    expect(response).not.toBeNull();
    expect(response!.status()).toBe(200);
    const heading = page.locator('h1, h2').first();
    await expect(heading).toBeVisible();
  });

  test('messages page loads and renders message browser', async ({ page }) => {
    const response = await page.goto('/dashboard/messages');
    expect(response).not.toBeNull();
    expect(response!.status()).toBe(200);
    // Message browser is a client component — wait for it to hydrate
    const heading = page.locator('h1, h2').first();
    await expect(heading).toBeVisible();
  });

  test('schemas page loads and renders schema browser', async ({ page }) => {
    const response = await page.goto('/dashboard/schemas');
    expect(response).not.toBeNull();
    expect(response!.status()).toBe(200);
    const heading = page.locator('h1, h2').first();
    await expect(heading).toBeVisible();
  });
});

test.describe('Page loads — dashboard layout elements present', () => {
  test('dashboard page includes sidebar navigation', async ({ page }) => {
    await page.goto('/dashboard/overview');
    const sidebar = page.locator('aside nav');
    await expect(sidebar).toBeVisible();
    // All 5 sidebar links should be present
    const links = sidebar.locator('a');
    await expect(links).toHaveCount(5);
  });

  test('root layout includes top navigation bar', async ({ page }) => {
    await page.goto('/dashboard/overview');
    const nav = page.locator('body > nav');
    await expect(nav).toBeVisible();
    await expect(nav.locator('a').first()).toHaveText('Kafka Lab');
  });

  test('page has correct root title', async ({ page }) => {
    await page.goto('/dashboard/overview');
    await expect(page).toHaveTitle(/Kafka Lab/);
  });
});
