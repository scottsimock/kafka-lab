---
id: TASK-27.8
title: SP0.011 — Next.js 15 on Azure Function Apps
status: Done
assignee:
  - tester-18
created_date: '2026-03-30 15:22'
updated_date: '2026-03-30 16:20'
labels:
  - research
milestone: m-0
dependencies: []
references:
  - 'https://nextjs.org/docs'
parent_task_id: TASK-27
priority: medium
ordinal: 11000
---

## Description

<!-- SECTION:DESCRIPTION:BEGIN -->
**Objective:** Research Next.js 15 App Router deployment on Azure Function Apps with VNet integration. The web application is the project's management UI — a 4-view dashboard that connects to Kafka brokers via confluent-kafka-javascript for real-time cluster monitoring and message browsing.\n\n**Sources:**\n- https://nextjs.org/docs (Next.js 15 documentation)\n- https://learn.microsoft.com/en-us/azure/azure-functions/functions-overview\n- https://github.com/confluentinc/confluent-kafka-javascript\n- https://learn.microsoft.com/en-us/azure/azure-functions/functions-networking-options\n- Azure Function Apps with Next.js deployment guides\n\n**Output:** A backlog document created via `backlog-document_create` containing:\n- Executive summary of web application architecture\n- Next.js 15 App Router patterns (server components, client components, route handlers)\n- API route handlers for Kafka operations (produce, consume, admin) using confluent-kafka-javascript\n- SSR on Azure Function Apps (custom server adapter, cold start optimization)\n- VNet integration for Function Apps (VNet injection, private endpoint access to Kafka)\n- 4-view dashboard architecture:\n  1. Cluster Overview (broker status, partition distribution, replication health)\n  2. Topic Detail (partitions, offsets, configuration)\n  3. Consumer Groups (lag monitoring, member assignment)\n  4. Message Browser (produce/consume messages with schema support)\n- Static assets and CDN strategy\n- Example project structure and API route\n- References with URLs\n\n**Scope:**\n- Include: App Router, API routes, confluent-kafka-javascript, Function Apps, VNet integration, dashboard views\n- Exclude: Infrastructure provisioning (SP0.008), CI/CD deployment (SP0.010), Kafka broker config (SP0.001)
<!-- SECTION:DESCRIPTION:END -->

## Acceptance Criteria
<!-- AC:BEGIN -->
- [x] #1 Document covers Next.js 15 App Router patterns (server components, client components, API routes)
- [x] #2 Document covers API route handlers using confluent-kafka-javascript for Kafka client operations
- [x] #3 Document covers deployment on Azure Function Apps with SSR support
- [x] #4 Document covers VNet integration for Function Apps accessing private Kafka brokers
- [x] #5 Document covers the 4-view dashboard architecture (cluster overview, topic detail, consumer groups, message browser)
<!-- AC:END -->

## Implementation Notes

<!-- SECTION:NOTES:BEGIN -->
## [Coder] 2026-03-30T12:09:00 EDT
- Researched Next.js 15 App Router patterns (server vs. client components, route handlers, streaming, error boundaries)
- Researched confluent-kafka-javascript KafkaJS-compatible API: producer, consumer, admin client (listTopics, describeGroups, consumer group lag)
- Researched Azure Function Apps custom handler pattern with Next.js standalone output
- Researched Azure Function Apps regional VNet integration, private endpoints, private DNS resolution for private Kafka brokers
- Created backlog document `doc-16 — SP0.011 — Next.js 15 on Azure Function Apps`
- Document covers all 5 AC items: App Router patterns, Kafka API routes with TypeScript examples, Azure Function Apps SSR deployment, VNet integration, 4-view dashboard architecture
- Document includes project structure directory tree, key API route implementation, host.json custom handler config, CDN/Front Door strategy, and 16 reference URLs
- All Kafka examples use async/await with proper connect/disconnect lifecycle in finally blocks
- Cold start optimisation strategies documented: standalone output, Always Ready instances, singleton client module

## [Tester] 2026-03-30T12:15:00 EDT

### Review Result: FAIL — 89.3% (threshold 95%)

| Category | Weight | Score | Weighted |
|---|---|---|---|
| Accuracy | 30% | 82 | 24.6 |
| Completeness | 25% | 97 | 24.25 |
| Sources | 20% | 90 | 18.0 |
| Documentation Quality | 15% | 95 | 14.25 |
| Actionability | 10% | 82 | 8.2 |
| **Total** | | | **89.3%** |

### Blocking Issues (Accuracy / Actionability)

**Issue 1 — Kafka client initialization uses wrong config API (Critical)**
The document initializes the KafkaJS-compatible Kafka client using librdkafka-style flat config keys:
```typescript
new Kafka({
  'bootstrap.servers': process.env.KAFKA_BOOTSTRAP_SERVERS!,
  'security.protocol': 'SSL',
  'ssl.ca.location': process.env.KAFKA_CA_CERT_PATH,
})
```
The `@confluentinc/kafka-javascript` KafkaJS-compatible API uses the KafkaJS constructor shape `{ brokers: string[], ssl: boolean | TlsOptions, ... }` — not librdkafka flat config keys. The code as written will not instantiate the client correctly and will mislead implementers.

**Issue 2 — `admin.listGroupOffsets({ groupId })` is not a valid KafkaJS admin method (Critical)**
Line 241: `const groupOffsets = await admin.listGroupOffsets({ groupId });`
This method does not exist in the KafkaJS API or the confluent-kafka-javascript KafkaJS-compatible wrapper. The correct method is `admin.fetchOffsets({ groupId, topics: [...] })`. This call will throw at runtime.

**Issue 3 — `RouteContext<T>` type is used but never imported or defined (Minor)**
Multiple route handler examples reference `RouteContext<{ name: string }>` and `RouteContext<{ groupId: string }>` as the second parameter type. This is not a standard Next.js 15 export. The actual second parameter type is `{ params: Promise<{ name: string }> }`. While the runtime usage (`await context.params`) is correct, the TypeScript type annotation will fail to compile.

### Non-blocking Observations

- Completeness is strong: all 5 AC items addressed, all 4 dashboard views documented with components, API routes, and refresh strategies.
- Sources are well-cited (16 URLs, strong primary source coverage from nextjs.org, docs.confluent.io, learn.microsoft.com).
- Document structure, executive summary, and overall readability are high quality.
- The two non-authoritative blog URLs (drcodes.com, altudo.co) are minor; the authoritative sources are present.
- UAMI secret retrieval from Key Vault at runtime is mentioned in the tech stack table but not detailed in any section — acceptable gap given scope.

### Required Fixes Before Pass

1. Correct the `getKafkaClient()` factory to use `{ brokers: process.env.KAFKA_BOOTSTRAP_SERVERS!.split(','), ssl: true, ... }` constructor shape.
2. Replace `admin.listGroupOffsets({ groupId })` with `admin.fetchOffsets({ groupId, topics: [...] })`.
3. Replace `RouteContext<T>` with the correct inline type `{ params: Promise<T> }` in all route handler signatures.

## [TL] Cycle 2 guidance — tester FAIL 89.3%
- CRITICAL: Fix Kafka client constructor in `lib/kafka/client.ts`. `@confluentinc/kafka-javascript` KafkaJS-compatible `Kafka` class expects KafkaJS shape: `{ brokers: string[], ssl: boolean | TlsOptions }` NOT librdkafka flat keys.
- CRITICAL: Fix `admin.listGroupOffsets()` which does not exist. Use `admin.fetchOffsets({ groupId, topics: [...] })` instead.
- Fix TypeScript: `RouteContext<T>` is not a Next.js 15 export. Use `{ params: Promise<{ name: string }> }` directly as the type.

## [Coder] 2026-03-30T12:30:00 EDT
- Applied 3 targeted fixes to doc-16 (SP0.011 — Next.js 15 on Azure Function Apps)
- Fix 1 (Critical/Accuracy): Replaced librdkafka flat-key constructor with KafkaJS shape `{ brokers: string[], ssl: true, sasl: { mechanism, username, password } }` in `lib/kafka/client.ts` singleton
- Fix 2 (Critical/Accuracy): Replaced non-existent `admin.listGroupOffsets({ groupId })` with correct KafkaJS `admin.fetchOffsets({ groupId, topics: [topic] })` in consumer group lag route; rewrote lag calculation loop to derive topics from `describeGroups` member assignments and compute committed vs. end offset diff using `fetchOffsets` + `fetchTopicOffsets`
- Fix 3 (Minor/TypeScript): Replaced all 3 occurrences of `RouteContext<T>` (non-existent Next.js 15 export) with correct inline type `{ params: Promise<T> }` in route handlers for `/api/topics/[name]` and `/api/consumer-groups/[groupId]/lag`; updated destructured `params` usage accordingly
- Verified: no `RouteContext`, `listGroupOffsets`, or `'bootstrap.servers'` flat keys remain in doc-16

## [Tester] 2026-03-30T12:45:00 EDT

### Review Result: PASS — 95.7% (threshold 95%)

| Category | Weight | Score | Weighted |
|---|---|---|---------|
| Accuracy | 30% | 97 | 29.1 |
| Completeness | 25% | 98 | 24.5 |
| Sources | 20% | 90 | 18.0 |
| Documentation Quality | 15% | 96 | 14.4 |
| Actionability | 10% | 97 | 9.7 |
| **Total** | | | **95.7%** |

### Cycle 2 Fixes Verified

- **Fix 1 (Critical/Accuracy)**: `getKafkaClient()` now uses KafkaJS constructor shape `{ brokers: string[], ssl: true, sasl: { mechanism, username, password } }` — confirmed at line 162. No `bootstrap.servers` flat keys remain.
- **Fix 2 (Critical/Accuracy)**: `admin.listGroupOffsets()` replaced with `admin.fetchOffsets({ groupId, topics: [topic] })` — confirmed at line 257. Lag calculation loop correctly derives topics from `describeGroups` member assignments and computes committed vs. end offset diff.
- **Fix 3 (Minor/TypeScript)**: All 3 `RouteContext<T>` occurrences replaced with correct inline type `{ params: Promise<T> }` — confirmed at lines 75, 207, 237.

### Remaining Non-Blocking Observations

- Two non-authoritative blog URLs (drcodes.com, altudo.co) keep Sources at 90; all primary sources present.
- Document is actionable as SP1 implementation guidance.
<!-- SECTION:NOTES:END -->
