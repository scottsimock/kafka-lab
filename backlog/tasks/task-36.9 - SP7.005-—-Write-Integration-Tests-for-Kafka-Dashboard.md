---
id: TASK-36.9
title: SP7.005 — Write Integration Tests for Kafka Dashboard
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
ordinal: 6505
---

## Description

<!-- SECTION:DESCRIPTION:BEGIN -->
Write Playwright integration tests for the Kafka dashboard features: topic listing displays actual topics from the cluster, consumer group list shows real consumer groups, metrics display shows broker and cluster health data. Tests interact with the live dev environment and verify real data flows through the UI.
<!-- SECTION:DESCRIPTION:END -->

## Acceptance Criteria
<!-- AC:BEGIN -->
- [ ] #1 Test: topic listing page shows topics from live Kafka cluster
- [ ] #2 Test: topic detail page displays partition count and replication factor and config
- [ ] #3 Test: consumer groups page lists active consumer groups with state badges
- [ ] #4 Test: consumer group detail shows member assignments and lag
- [ ] #5 Test: cluster metrics page displays broker count and health status
- [ ] #6 Tests use real data from the dev environment (not mocks)
- [ ] #7 Tests organized in webapp/tests/e2e/dashboard/
<!-- AC:END -->
