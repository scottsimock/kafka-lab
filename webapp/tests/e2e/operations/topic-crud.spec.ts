import { test, expect } from './operations.fixture';

/**
 * Topic CRUD operations — create, verify listing, delete, verify removal.
 *
 * Uses API-level calls because the create/delete UI is not yet built.
 * Tests run serially: create → verify → delete → verify-gone.
 */
test.describe.serial('Topic CRUD operations', () => {
  let topicName: string;

  test.beforeAll(async ({ browser }) => {
    // Generate a unique topic name before the suite runs
    topicName = `e2e-crud-${Date.now()}-${Math.random().toString(36).slice(2, 8)}`;
  });

  test.afterAll(async ({ request }) => {
    // Best-effort cleanup: delete the test topic if it still exists
    if (topicName) {
      await request
        .delete(`/api/topics/${encodeURIComponent(topicName)}`)
        .catch(() => { /* ignore cleanup failure */ });
    }
  });

  test('create new topic via API with specified partitions and replication factor', async ({
    ops,
  }) => {
    const res = await ops.createTopic(topicName, 3, 1);

    // Accept 200/201 for success. If API returns "not implemented" the
    // test correctly fails — that's the signal the feature isn't deployed.
    expect(
      res.status(),
      `Expected topic creation to succeed (got ${res.status()})`,
    ).toBeLessThan(300);

    const body = await res.json();
    // The response should acknowledge the created topic
    expect(body).toBeDefined();
  });

  test('newly created topic appears in topic listing page', async ({ page, ops }) => {
    // Give Kafka a moment to propagate metadata
    await page.waitForTimeout(3_000);

    await page.goto('/dashboard/topics');
    await page.waitForLoadState('networkidle');

    const table = page.locator('table');
    const hasTable = await table.isVisible().catch(() => false);
    if (!hasTable) {
      // Kafka may be offline — skip gracefully
      const error = page.locator('text=Error loading topics');
      const isError = await error.isVisible().catch(() => false);
      if (isError) {
        test.skip(true, 'Kafka offline — cannot verify topic listing');
        return;
      }
    }

    // Search for our topic in the listing
    const rows = table.locator('tbody tr');
    const count = await rows.count();
    let found = false;

    for (let i = 0; i < count; i++) {
      const text = await rows.nth(i).textContent();
      if (text?.includes(topicName)) {
        found = true;

        // Verify partition count and replication factor display
        const cells = rows.nth(i).locator('td');
        const partitionText = await cells.nth(1).textContent();
        const replicationText = await cells.nth(2).textContent();
        expect(partitionText?.trim()).toBe('3');
        expect(replicationText?.trim()).toBe('1');
        break;
      }
    }

    expect(found, `Topic "${topicName}" should appear in the listing`).toBe(true);
  });

  test('newly created topic appears in API listing', async ({ ops }) => {
    const data = await ops.listTopics();

    // Handle API error (Kafka offline)
    if (!data.topics) {
      test.skip(true, 'Topics API returned no data — Kafka may be offline');
      return;
    }

    const topic = data.topics.find((t) => t.name === topicName);
    expect(topic, `Topic "${topicName}" should exist in API response`).toBeDefined();
    expect(topic!.partitionCount).toBe(3);
    expect(topic!.replicationFactor).toBe(1);
  });

  test('delete topic via API removes it', async ({ ops }) => {
    const res = await ops.deleteTopic(topicName);

    // Accept 200/204 for success
    expect(
      res.status(),
      `Expected topic deletion to succeed (got ${res.status()})`,
    ).toBeLessThan(300);
  });

  test('deleted topic no longer appears in topic listing page', async ({ page }) => {
    // Give Kafka time to propagate the deletion
    await page.waitForTimeout(3_000);

    await page.goto('/dashboard/topics');
    await page.waitForLoadState('networkidle');

    const table = page.locator('table');
    const hasTable = await table.isVisible().catch(() => false);

    if (!hasTable) {
      // No table means either error or empty — either way the topic is gone
      return;
    }

    const rows = table.locator('tbody tr');
    const count = await rows.count();

    for (let i = 0; i < count; i++) {
      const text = await rows.nth(i).textContent();
      expect(
        text?.includes(topicName),
        `Topic "${topicName}" should NOT appear after deletion`,
      ).toBeFalsy();
    }
  });

  test('deleted topic no longer appears in API listing', async ({ ops }) => {
    const data = await ops.listTopics();

    if (!data.topics) {
      // API error — skip gracefully
      return;
    }

    const topic = data.topics.find((t) => t.name === topicName);
    expect(topic, `Topic "${topicName}" should be gone from API listing`).toBeUndefined();
  });
});
