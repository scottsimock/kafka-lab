---
id: TASK-36.3
title: SP7.006 — Write Integration Tests for Kafka Operations
status: To Do
assignee: []
created_date: '2026-03-31 22:01'
updated_date: '2026-03-31 22:01'
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
- [ ] #1 Test: create new topic via UI with specified partition count and replication factor
- [ ] #2 Test: verify newly created topic appears in topic listing
- [ ] #3 Test: produce message to topic via UI and confirm success
- [ ] #4 Test: consume message from topic via UI and verify content matches
- [ ] #5 Test: message round-trip (produce then consume) validates data integrity
- [ ] #6 Test: topic deletion via UI removes topic from listing
- [ ] #7 Tests organized in webapp/tests/e2e/operations/
<!-- AC:END -->
