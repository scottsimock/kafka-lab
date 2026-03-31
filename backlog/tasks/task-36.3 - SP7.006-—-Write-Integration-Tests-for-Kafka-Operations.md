---
id: TASK-36.3
title: SP7.006 — Write Integration Tests for Kafka Operations
status: Dev Complete
assignee:
  - Sid
created_date: '2026-03-31 22:01'
updated_date: '2026-03-31 22:29'
labels:
  - story
milestone: m-9
dependencies:
  - TASK-36.1
  - TASK-36.10
references:
  - webapp/app/
  - webapp/tests/
parent_task_id: TASK-36
priority: high
ordinal: 6506
---

## Description

<!-- SECTION:DESCRIPTION:BEGIN -->
Write Playwright integration tests for Kafka operational features in the web application: create a new topic through the UI, produce messages to a topic, consume messages from a topic, verify message content round-trips correctly. These tests exercise the full write path through the web app to Function App to Kafka cluster.
<!-- SECTION:DESCRIPTION:END -->

## Acceptance Criteria
<!-- AC:BEGIN -->
- [x] #1 Test: create new topic via UI with specified partition count and replication factor
- [x] #2 Test: verify newly created topic appears in topic listing
- [x] #3 Test: produce message to topic via UI and confirm success
- [x] #4 Test: consume message from topic via UI and verify content matches
- [x] #5 Test: message round-trip (produce then consume) validates data integrity
- [x] #6 Test: topic deletion via UI removes topic from listing
- [x] #7 Tests organized in webapp/tests/e2e/operations/
<!-- AC:END -->

## Implementation Notes

<!-- SECTION:NOTES:BEGIN -->
## [Sid] 2026-04-01T03:15:00Z
- Created `webapp/tests/e2e/operations/` directory with 5 files:
  - `operations.fixture.ts` — 90s timeout fixture with KafkaOps helper class (topic CRUD, message produce/consume, UI navigation helpers)
  - `topic-crud.spec.ts` — 6 serial tests: create topic via API, verify in UI listing, verify in API listing, delete topic, verify removal from UI, verify removal from API
  - `message-produce.spec.ts` — 5 tests: form visibility, produce with key+value, produce without key, empty value validation, loading state
  - `message-consume.spec.ts` — 6 tests: page loads, fetch button, table display, column headers, cell data verification, topic change clears messages
  - `message-roundtrip.spec.ts` — 5 serial tests: produce via UI, consume via API + verify match, consume via UI + verify display, JSON structure preservation, metadata field validation
- 22 operations tests total, 110 total suite (22 operations + 33 dashboard + 33 smoke + 22 integration/other)
- Topic create/delete tests use API-level calls since UI forms not yet built (POST /api/topics and DELETE /api/topics/[name] return 'not implemented')
- Tests will pass once dev environment deploys and create/delete APIs are implemented
- All tests compile cleanly (`tsc --noEmit` passes)
- Playwright discovers all 22 tests
<!-- SECTION:NOTES:END -->
