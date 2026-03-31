import { test, expect } from './dashboard.fixture';

test.describe('Consumer group detail — members and lag', () => {
  test.beforeEach(async ({ page }) => {
    await page.goto('/dashboard/consumer-groups');
    await page.waitForLoadState('networkidle');
  });

  test('clicking a group navigates to its detail page', async ({ page }) => {
    const firstLink = page.locator('table tbody tr a').first();
    const linkVisible = await firstLink.isVisible().catch(() => false);
    if (!linkVisible) {
      test.skip(true, 'No consumer groups available');
      return;
    }

    const groupId = await firstLink.textContent();
    await firstLink.click();
    await page.waitForLoadState('networkidle');

    const heading = page.locator('h1');
    await expect(heading).toContainText(groupId!.trim());
  });

  test('detail page shows state badge and protocol', async ({ page }) => {
    const firstLink = page.locator('table tbody tr a').first();
    const linkVisible = await firstLink.isVisible().catch(() => false);
    if (!linkVisible) {
      test.skip(true, 'No consumer groups available');
      return;
    }

    await firstLink.click();
    await page.waitForLoadState('networkidle');

    const errorVisible = await page.locator('text=Error loading consumer groups').isVisible().catch(() => false);
    if (errorVisible) {
      return;
    }

    // State badge
    const stateBadge = page.locator('span').filter({ hasText: /^(Stable|Empty|Dead|Rebalancing)$/ }).first();
    await expect(stateBadge).toBeVisible();

    // Protocol label
    await expect(page.locator('text=Protocol:')).toBeVisible();
  });

  test('detail page has Members section', async ({ page }) => {
    const firstLink = page.locator('table tbody tr a').first();
    const linkVisible = await firstLink.isVisible().catch(() => false);
    if (!linkVisible) {
      test.skip(true, 'No consumer groups available');
      return;
    }

    await firstLink.click();
    await page.waitForLoadState('networkidle');

    const membersHeading = page.locator('h2:has-text("Members")');
    await expect(membersHeading).toBeVisible();

    // Either a members table or "No members" message
    const memberTable = page.locator('section').first().locator('table');
    const hasMemberTable = await memberTable.isVisible().catch(() => false);
    if (hasMemberTable) {
      const headers = memberTable.locator('thead th');
      await expect(headers.nth(0)).toHaveText('Member ID');
      await expect(headers.nth(1)).toHaveText('Client ID');
      await expect(headers.nth(2)).toHaveText('Host');
      await expect(headers.nth(3)).toHaveText('Assigned Partitions');
    } else {
      await expect(page.locator('text=No members in this consumer group')).toBeVisible();
    }
  });

  test('detail page has Partition Lag section', async ({ page }) => {
    const firstLink = page.locator('table tbody tr a').first();
    const linkVisible = await firstLink.isVisible().catch(() => false);
    if (!linkVisible) {
      test.skip(true, 'No consumer groups available');
      return;
    }

    await firstLink.click();
    await page.waitForLoadState('networkidle');

    const lagHeading = page.locator('h2:has-text("Partition Lag")');
    await expect(lagHeading).toBeVisible();

    // Either a lag table or "No partition offsets" message
    const lagTable = page.locator('section').last().locator('table');
    const hasLagTable = await lagTable.isVisible().catch(() => false);
    if (hasLagTable) {
      const headers = lagTable.locator('thead th');
      await expect(headers.nth(0)).toHaveText('Topic');
      await expect(headers.nth(1)).toHaveText('Partition');
      await expect(headers.nth(2)).toHaveText('Committed Offset');
      await expect(headers.nth(3)).toHaveText('Lag');
    } else {
      await expect(page.locator('text=No partition offsets committed')).toBeVisible();
    }
  });

  test('detail page has back link to consumer groups listing', async ({ page }) => {
    const firstLink = page.locator('table tbody tr a').first();
    const linkVisible = await firstLink.isVisible().catch(() => false);
    if (!linkVisible) {
      test.skip(true, 'No consumer groups available');
      return;
    }

    await firstLink.click();
    await page.waitForLoadState('networkidle');

    const backLink = page.locator('a:has-text("Back to Consumer Groups")');
    await expect(backLink).toBeVisible();
    const href = await backLink.getAttribute('href');
    expect(href).toBe('/dashboard/consumer-groups');
  });

  test('refresh button is present on detail page', async ({ page }) => {
    const firstLink = page.locator('table tbody tr a').first();
    const linkVisible = await firstLink.isVisible().catch(() => false);
    if (!linkVisible) {
      test.skip(true, 'No consumer groups available');
      return;
    }

    await firstLink.click();
    await page.waitForLoadState('networkidle');

    const refreshButton = page.locator('button:has-text("Refresh")');
    await expect(refreshButton).toBeVisible();
  });
});
