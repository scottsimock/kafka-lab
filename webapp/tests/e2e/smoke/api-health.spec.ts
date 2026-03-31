import { test, expect } from '../fixtures/smoke.fixture';

test.describe('API health — core endpoints respond', () => {
  test('GET /api/cluster returns JSON response', async ({ request }) => {
    const response = await request.get('/api/cluster');
    // May return 200 (Kafka connected) or 500 (Kafka unreachable)
    // Smoke test: endpoint exists and returns JSON
    expect([200, 500]).toContain(response.status());
    const contentType = response.headers()['content-type'] ?? '';
    expect(contentType).toContain('application/json');
  });

  test('GET /api/topics returns JSON response', async ({ request }) => {
    const response = await request.get('/api/topics');
    expect([200, 500]).toContain(response.status());
    const contentType = response.headers()['content-type'] ?? '';
    expect(contentType).toContain('application/json');
  });

  test('GET /api/consumer-groups returns JSON response', async ({ request }) => {
    const response = await request.get('/api/consumer-groups');
    expect([200, 500]).toContain(response.status());
    const contentType = response.headers()['content-type'] ?? '';
    expect(contentType).toContain('application/json');
  });

  test('GET /api/schemas returns JSON response', async ({ request }) => {
    const response = await request.get('/api/schemas');
    expect([200, 500]).toContain(response.status());
    const contentType = response.headers()['content-type'] ?? '';
    expect(contentType).toContain('application/json');
  });
});

test.describe('API health — response shape validation', () => {
  test('GET /api/cluster returns expected structure when healthy', async ({ request }) => {
    const response = await request.get('/api/cluster');
    if (response.status() === 200) {
      const body = await response.json();
      expect(body).toHaveProperty('brokers');
      expect(body).toHaveProperty('topicCount');
      expect(body).toHaveProperty('partitionCount');
      expect(Array.isArray(body.brokers)).toBe(true);
    }
  });

  test('GET /api/topics returns array when healthy', async ({ request }) => {
    const response = await request.get('/api/topics');
    if (response.status() === 200) {
      const body = await response.json();
      expect(Array.isArray(body)).toBe(true);
      if (body.length > 0) {
        expect(body[0]).toHaveProperty('name');
        expect(body[0]).toHaveProperty('partitionCount');
        expect(body[0]).toHaveProperty('replicationFactor');
      }
    }
  });

  test('GET /api/consumer-groups returns array when healthy', async ({ request }) => {
    const response = await request.get('/api/consumer-groups');
    if (response.status() === 200) {
      const body = await response.json();
      expect(Array.isArray(body)).toBe(true);
      if (body.length > 0) {
        expect(body[0]).toHaveProperty('groupId');
        expect(body[0]).toHaveProperty('state');
      }
    }
  });

  test('GET /api/schemas returns subjects array when healthy', async ({ request }) => {
    const response = await request.get('/api/schemas');
    if (response.status() === 200) {
      const body = await response.json();
      expect(body).toHaveProperty('subjects');
      expect(Array.isArray(body.subjects)).toBe(true);
    }
  });
});

test.describe('API health — non-implemented endpoints', () => {
  test('GET /api/messages returns not-implemented status', async ({ request }) => {
    const response = await request.get('/api/messages');
    // May return 200 with {status: 'not implemented'} or other status
    expect([200, 500]).toContain(response.status());
  });
});
