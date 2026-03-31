import { test, expect } from '../fixtures/smoke.fixture';

test.describe('Navigation — top nav bar links', () => {
  test('clicking Kafka Lab logo navigates to home', async ({ page }) => {
    await page.goto('/dashboard/topics');
    await page.locator('body > nav a', { hasText: 'Kafka Lab' }).click();
    // Home redirects to /dashboard/overview
    await page.waitForURL('**/dashboard/overview');
    expect(page.url()).toContain('/dashboard/overview');
  });

  test('clicking Dashboard link navigates to overview', async ({ page }) => {
    await page.goto('/dashboard/topics');
    await page.locator('body > nav a', { hasText: 'Dashboard' }).click();
    await page.waitForURL('**/dashboard/overview');
    expect(page.url()).toContain('/dashboard/overview');
  });
});

test.describe('Navigation — sidebar links resolve to valid pages', () => {
  const sidebarLinks = [
    { text: 'Overview', path: '/dashboard/overview' },
    { text: 'Topics', path: '/dashboard/topics' },
    { text: 'Consumer Groups', path: '/dashboard/consumer-groups' },
    { text: 'Messages', path: '/dashboard/messages' },
    { text: 'Schemas', path: '/dashboard/schemas' },
  ];

  for (const link of sidebarLinks) {
    test(`sidebar link "${link.text}" navigates to ${link.path}`, async ({ page }) => {
      await page.goto('/dashboard/overview');
      const sidebar = page.locator('aside nav');
      await sidebar.locator('a', { hasText: link.text }).click();
      await page.waitForURL(`**${link.path}`);
      expect(page.url()).toContain(link.path);
      // Page should load successfully with visible content
      const heading = page.locator('h1, h2').first();
      await expect(heading).toBeVisible();
    });
  }
});

test.describe('Navigation — back links on detail pages', () => {
  test('topics detail page has back link to topics list', async ({ page }) => {
    // Navigate to topics page first, then try to access a detail if links exist
    await page.goto('/dashboard/topics');
    const topicLinks = page.locator('table a[href*="/dashboard/topics/"]');
    const linkCount = await topicLinks.count();
    if (linkCount > 0) {
      await topicLinks.first().click();
      await page.waitForURL('**/dashboard/topics/**');
      const backLink = page.locator('a[href="/dashboard/topics"]');
      await expect(backLink).toBeVisible();
      await backLink.click();
      await page.waitForURL('**/dashboard/topics');
      expect(page.url()).toMatch(/\/dashboard\/topics\/?$/);
    }
  });

  test('consumer group detail page has back link to groups list', async ({ page }) => {
    await page.goto('/dashboard/consumer-groups');
    const groupLinks = page.locator('table a[href*="/dashboard/consumer-groups/"]');
    const linkCount = await groupLinks.count();
    if (linkCount > 0) {
      await groupLinks.first().click();
      await page.waitForURL('**/dashboard/consumer-groups/**');
      const backLink = page.locator('a[href="/dashboard/consumer-groups"]');
      await expect(backLink).toBeVisible();
      await backLink.click();
      await page.waitForURL('**/dashboard/consumer-groups');
      expect(page.url()).toMatch(/\/dashboard\/consumer-groups\/?$/);
    }
  });

  test('schema detail page has back link to schemas list', async ({ page }) => {
    await page.goto('/dashboard/schemas');
    const subjectLinks = page.locator('table a[href*="/dashboard/schemas/"]');
    const linkCount = await subjectLinks.count();
    if (linkCount > 0) {
      await subjectLinks.first().click();
      await page.waitForURL('**/dashboard/schemas/**');
      const backLink = page.locator('a[href="/dashboard/schemas"]');
      await expect(backLink).toBeVisible();
      await backLink.click();
      await page.waitForURL('**/dashboard/schemas');
      expect(page.url()).toMatch(/\/dashboard\/schemas\/?$/);
    }
  });
});
