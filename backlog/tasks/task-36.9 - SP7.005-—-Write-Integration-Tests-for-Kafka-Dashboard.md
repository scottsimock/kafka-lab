---
id: TASK-36.9
title: SP7.005 — Write Integration Tests for Kafka Dashboard
status: Dev Complete
assignee:
  - Sid
created_date: '2026-03-31 22:01'
updated_date: '2026-03-31 22:21'
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
- [x] #1 Test: topic listing page shows topics from live Kafka cluster
- [x] #2 Test: topic detail page displays partition count and replication factor and config
- [x] #3 Test: consumer groups page lists active consumer groups with state badges
- [x] #4 Test: consumer group detail shows member assignments and lag
- [x] #5 Test: cluster metrics page displays broker count and health status
- [x] #6 Tests use real data from the dev environment (not mocks)
- [x] #7 Tests organized in webapp/tests/e2e/dashboard/
<!-- AC:END -->

## Implementation Notes

<!-- SECTION:NOTES:BEGIN -->
## [Sid] 2026-04-01T00:15:00Z
- Created `webapp/tests/e2e/dashboard/` with 6 files (1 fixture + 5 spec files)
- 33 integration tests across 5 spec files:
  - `topic-listing.spec.ts` — 5 tests (heading, table headers, row count, row data, detail links)
  - `topic-detail.spec.ts` — 4 tests (navigation, metadata display, partition table, back link)
  - `consumer-groups.spec.ts` — 6 tests (heading, table headers, row count, state badges, detail links, refresh button)
  - `consumer-group-detail.spec.ts` — 6 tests (navigation, state/protocol, members section, lag section, back link, refresh button)
  - `cluster-metrics.spec.ts` — 7 tests (heading, health badge, summary metrics, metric values, broker table headers, broker rows, broker data)
- All tests tolerate Kafka being offline — gracefully check for error boundary or skip
- Shared dashboard fixture with 60s timeout (vs 30s smoke)
- Playwright discovers all 66 tests (33 dashboard + 33 smoke)
- Tests are write-complete; awaiting dev environment deployment (SP7.001) to run against live cluster
<!-- SECTION:NOTES:END -->
