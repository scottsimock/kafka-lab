import { test, expect } from './operations.fixture';

/**
 * Message round-trip tests — produce a message then consume it,
 * verifying end-to-end data integrity through the full write path:
 * UI → Next.js API → Azure Function App → Kafka → consume API → UI.
 *
 * Tests run serially because consumption depends on prior production.
 */
test.describe.serial('Message round-trip (produce → consume)', () => {
  const testKey = `e2e-roundtrip-${Date.now()}`;
  const testValue = JSON.stringify({
    test: 'roundtrip',
    ts: Date.now(),
    payload: 'The quick brown fox jumps over the lazy dog',
  });
  let selectedTopic = '';

  test('select a topic and produce a message via UI', async ({ page }) => {
    await page.goto('/dashboard/messages');
    await page.waitForLoadState('networkidle');

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

    selectedTopic = await select.inputValue();
    expect(selectedTopic.length).toBeGreaterThan(0);

    // Fill and submit the produce form
    await page.locator('#key-input').fill(testKey);
    await page.locator('#value-input').fill(testValue);
    await page.locator('button:has-text("Produce Message")').click();

    // Confirm success
    await expect(
      page.locator('text=Message produced successfully!'),
    ).toBeVisible({ timeout: 30_000 });
  });

  test('consume message via API and verify content matches', async ({ ops }) => {
    if (!selectedTopic) {
      test.skip(true, 'No topic selected — previous test may have been skipped');
      return;
    }

    // Allow time for Kafka to replicate the message
    await new Promise((r) => setTimeout(r, 5_000));

    const data = await ops.consumeMessages(selectedTopic, 50);

    expect(data.messages).toBeDefined();
    expect(Array.isArray(data.messages)).toBe(true);

    // Find our specific message by key
    const ourMessage = data.messages.find((m) => m.key === testKey);
    expect(
      ourMessage,
      `Expected to find message with key "${testKey}" in consumed messages`,
    ).toBeDefined();

    expect(ourMessage!.value).toBe(testValue);
  });

  test('consume message via UI and verify content displays', async ({ page }) => {
    if (!selectedTopic) {
      test.skip(true, 'No topic selected — previous test may have been skipped');
      return;
    }

    await page.goto('/dashboard/messages');
    await page.waitForLoadState('networkidle');

    const select = page.locator('#topic-select');
    await select.selectOption(selectedTopic);

    // Fetch messages
    await page.locator('button:has-text("Fetch Messages")').click();
    await expect(
      page.locator('button:has-text("Fetch Messages")'),
    ).toBeVisible({ timeout: 30_000 });

    const table = page.locator('table');
    const hasTable = await table.isVisible().catch(() => false);

    if (!hasTable) {
      test.skip(true, 'Message table not visible — fetch may have returned empty');
      return;
    }

    // Look for our message key in the table
    const rows = table.locator('tbody tr');
    const rowCount = await rows.count();
    let foundRow = -1;

    for (let i = 0; i < rowCount; i++) {
      const keyCell = await rows.nth(i).locator('td').first().textContent();
      if (keyCell?.includes(testKey)) {
        foundRow = i;
        break;
      }
    }

    expect(
      foundRow,
      `Expected to find a row with key "${testKey}" in the message table`,
    ).toBeGreaterThanOrEqual(0);

    // Verify the value cell contains our test data (may be truncated)
    const valueCell = rows.nth(foundRow).locator('td').nth(1);
    const valueText = await valueCell.textContent();
    expect(valueText).toContain('roundtrip');
    expect(valueText).toContain('The quick brown fox');
  });

  test('round-trip preserves JSON structure', async ({ ops }) => {
    if (!selectedTopic) {
      test.skip(true, 'No topic selected — previous test may have been skipped');
      return;
    }

    const data = await ops.consumeMessages(selectedTopic, 50);
    const ourMessage = data.messages.find((m) => m.key === testKey);

    if (!ourMessage) {
      test.skip(true, 'Message not found in second consume — consumer group offset issue');
      return;
    }

    // Parse the value as JSON to verify structure survived the round-trip
    const parsed = JSON.parse(ourMessage.value!);
    expect(parsed.test).toBe('roundtrip');
    expect(parsed.payload).toBe('The quick brown fox jumps over the lazy dog');
    expect(typeof parsed.ts).toBe('number');
  });

  test('message metadata fields are present and valid', async ({ ops }) => {
    if (!selectedTopic) {
      test.skip(true, 'No topic selected — previous test may have been skipped');
      return;
    }

    const data = await ops.consumeMessages(selectedTopic, 50);
    const ourMessage = data.messages.find((m) => m.key === testKey);

    if (!ourMessage) {
      test.skip(true, 'Message not found — cannot verify metadata');
      return;
    }

    // Partition should be a non-negative integer
    expect(ourMessage.partition).toBeGreaterThanOrEqual(0);

    // Offset should be a non-negative integer string
    expect(Number(ourMessage.offset)).toBeGreaterThanOrEqual(0);

    // Timestamp should be a non-empty string parseable as a number
    expect(ourMessage.timestamp.length).toBeGreaterThan(0);
    expect(Number(ourMessage.timestamp)).toBeGreaterThan(0);
  });
});
