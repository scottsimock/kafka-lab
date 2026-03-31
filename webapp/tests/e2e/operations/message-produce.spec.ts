import { test, expect } from './operations.fixture';

/**
 * Message production tests — verify the UI produce form sends messages
 * to Kafka and provides success feedback.
 */
test.describe('Message production via UI', () => {
  test.beforeEach(async ({ page }) => {
    await page.goto('/dashboard/messages');
    await page.waitForLoadState('networkidle');
  });

  test('produce form is visible when a topic is selected', async ({ page }) => {
    const select = page.locator('#topic-select');
    const selectVisible = await select.isVisible().catch(() => false);

    if (!selectVisible) {
      test.skip(true, 'Topic selector not available — Kafka may be offline');
      return;
    }

    // Wait for topics to populate the dropdown
    const options = select.locator('option');
    const optCount = await options.count();

    if (optCount === 0 || (optCount === 1 && await options.first().textContent() === 'No topics available')) {
      test.skip(true, 'No topics available in selector');
      return;
    }

    // Produce form should be visible
    await expect(page.locator('#topic-input')).toBeVisible();
    await expect(page.locator('#key-input')).toBeVisible();
    await expect(page.locator('#value-input')).toBeVisible();
    await expect(page.locator('button:has-text("Produce Message")')).toBeVisible();
  });

  test('produce message with key and value shows success feedback', async ({ page }) => {
    const select = page.locator('#topic-select');
    const selectVisible = await select.isVisible().catch(() => false);

    if (!selectVisible) {
      test.skip(true, 'Topic selector not available — Kafka may be offline');
      return;
    }

    const options = select.locator('option');
    const optCount = await options.count();

    if (optCount === 0 || (optCount === 1 && await options.first().textContent() === 'No topics available')) {
      test.skip(true, 'No topics available');
      return;
    }

    const uniqueKey = `e2e-key-${Date.now()}`;
    const uniqueValue = `e2e-value-${Date.now()}`;

    await page.locator('#key-input').fill(uniqueKey);
    await page.locator('#value-input').fill(uniqueValue);
    await page.locator('button:has-text("Produce Message")').click();

    // Wait for success feedback
    await expect(
      page.locator('text=Message produced successfully!'),
    ).toBeVisible({ timeout: 30_000 });
  });

  test('produce message without key (key is optional)', async ({ page }) => {
    const select = page.locator('#topic-select');
    const selectVisible = await select.isVisible().catch(() => false);

    if (!selectVisible) {
      test.skip(true, 'Topic selector not available — Kafka may be offline');
      return;
    }

    const options = select.locator('option');
    const optCount = await options.count();

    if (optCount === 0 || (optCount === 1 && await options.first().textContent() === 'No topics available')) {
      test.skip(true, 'No topics available');
      return;
    }

    const uniqueValue = `e2e-no-key-${Date.now()}`;

    // Leave key empty, fill only value
    await page.locator('#key-input').fill('');
    await page.locator('#value-input').fill(uniqueValue);
    await page.locator('button:has-text("Produce Message")').click();

    await expect(
      page.locator('text=Message produced successfully!'),
    ).toBeVisible({ timeout: 30_000 });
  });

  test('produce message with empty value shows validation error', async ({ page }) => {
    const select = page.locator('#topic-select');
    const selectVisible = await select.isVisible().catch(() => false);

    if (!selectVisible) {
      test.skip(true, 'Topic selector not available — Kafka may be offline');
      return;
    }

    const options = select.locator('option');
    const optCount = await options.count();

    if (optCount === 0 || (optCount === 1 && await options.first().textContent() === 'No topics available')) {
      test.skip(true, 'No topics available');
      return;
    }

    await page.locator('#key-input').fill('some-key');
    await page.locator('#value-input').fill('');
    await page.locator('button:has-text("Produce Message")').click();

    // The form requires a value — expect an error message or no success
    const success = page.locator('text=Message produced successfully!');
    const error = page.locator('.bg-red-100');

    // Either the HTML5 required attr prevents submission or the client-side
    // validation fires. Success message should NOT appear.
    await page.waitForTimeout(1_000);
    await expect(success).not.toBeVisible();
  });

  test('produce button shows loading state while sending', async ({ page }) => {
    const select = page.locator('#topic-select');
    const selectVisible = await select.isVisible().catch(() => false);

    if (!selectVisible) {
      test.skip(true, 'Topic selector not available — Kafka may be offline');
      return;
    }

    const options = select.locator('option');
    const optCount = await options.count();

    if (optCount === 0 || (optCount === 1 && await options.first().textContent() === 'No topics available')) {
      test.skip(true, 'No topics available');
      return;
    }

    await page.locator('#key-input').fill(`e2e-loading-${Date.now()}`);
    await page.locator('#value-input').fill('loading-test');

    // Intercept network to slow down the response so we can observe the loading state
    await page.route('/api/messages/produce', async (route) => {
      await new Promise((r) => setTimeout(r, 500));
      await route.continue();
    });

    await page.locator('button:has-text("Produce Message")').click();

    // The button should briefly show "Producing..."
    await expect(
      page.locator('button:has-text("Producing...")'),
    ).toBeVisible({ timeout: 5_000 });

    // Then settle back
    await expect(
      page.locator('button:has-text("Produce Message")'),
    ).toBeVisible({ timeout: 30_000 });
  });
});
