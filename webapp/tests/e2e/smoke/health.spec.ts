import { test, expect } from '@playwright/test';

test('app responds at base URL', async ({ page }) => {
  const response = await page.goto('/');
  expect(response).not.toBeNull();
  expect(response!.status()).toBeLessThan(500);
});
