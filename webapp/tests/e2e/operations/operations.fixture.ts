import { test as base, expect, type Page, type APIRequestContext } from '@playwright/test';

/** Unique suffix to prevent topic name collisions across parallel runs. */
function uniqueSuffix(): string {
  return `${Date.now()}-${Math.random().toString(36).slice(2, 8)}`;
}

/**
 * Helper utilities shared by Kafka operations tests.
 * Provides topic lifecycle management and message I/O wrappers
 * so individual spec files stay focused on assertions.
 */
export class KafkaOps {
  constructor(
    private readonly page: Page,
    private readonly request: APIRequestContext,
  ) {}

  /** Generate a collision-free topic name for test isolation. */
  topicName(prefix = 'e2e-test'): string {
    return `${prefix}-${uniqueSuffix()}`;
  }

  /**
   * Create a topic via the API.
   * Returns the response for status/body assertions.
   */
  async createTopic(name: string, partitions: number, replicationFactor: number) {
    return this.request.post('/api/topics', {
      data: { name, partitions, replicationFactor },
    });
  }

  /**
   * Delete a topic via the API.
   * Returns the response for status/body assertions.
   */
  async deleteTopic(name: string) {
    return this.request.delete(`/api/topics/${encodeURIComponent(name)}`);
  }

  /** Fetch the topic list from the API. Returns parsed JSON. */
  async listTopics() {
    const res = await this.request.get('/api/topics');
    return res.json() as Promise<{
      topics: Array<{ name: string; partitionCount: number; replicationFactor: number }>;
    }>;
  }

  /** Produce a message via the API. Returns the response. */
  async produceMessage(topic: string, key: string | undefined, value: string) {
    return this.request.post('/api/messages/produce', {
      data: { topic, key, value },
    });
  }

  /** Consume messages via the API. Returns parsed JSON. */
  async consumeMessages(topic: string, limit = 20) {
    const res = await this.request.get(
      `/api/messages/consume?topic=${encodeURIComponent(topic)}&limit=${limit}`,
    );
    return res.json() as Promise<{
      messages: Array<{
        key: string | undefined;
        value: string | undefined;
        partition: number;
        offset: string;
        timestamp: string;
      }>;
    }>;
  }

  /** Navigate to the messages page and wait for topic selector to load. */
  async goToMessages() {
    await this.page.goto('/dashboard/messages');
    await this.page.waitForLoadState('networkidle');
  }

  /** Select a topic in the message browser dropdown. */
  async selectTopic(topicName: string) {
    const select = this.page.locator('#topic-select');
    await expect(select).toBeVisible();
    await select.selectOption(topicName);
  }

  /**
   * Produce a message through the UI form.
   * Assumes the page is on /dashboard/messages with the target topic selected.
   */
  async produceViaUI(key: string, value: string) {
    const keyInput = this.page.locator('#key-input');
    const valueInput = this.page.locator('#value-input');
    const submitBtn = this.page.locator('button:has-text("Produce Message")');

    await keyInput.fill(key);
    await valueInput.fill(value);
    await submitBtn.click();
  }

  /** Click "Fetch Messages" and wait for the table to update. */
  async fetchMessagesViaUI() {
    const fetchBtn = this.page.locator('button:has-text("Fetch Messages")');
    await fetchBtn.click();
    // Wait for loading to complete
    await expect(fetchBtn).not.toHaveText('Fetching...', { timeout: 30_000 });
  }
}

/**
 * Extended test fixture for Kafka operations.
 * 90-second timeout — topic creation propagation and message
 * round-trips through a live Kafka cluster are slow.
 */
export const test = base.extend<{ ops: KafkaOps }>({
  ops: async ({ page, request }, use) => {
    await use(new KafkaOps(page, request));
  },
});

test.beforeEach(async ({}, testInfo) => {
  testInfo.setTimeout(90_000);
});

export { expect };
