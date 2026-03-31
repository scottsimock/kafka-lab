---
id: TASK-32.1
title: SP5.003 — Kafka API Route Handlers
status: Dev Complete
assignee:
  - Dallas
created_date: '2026-03-30 16:46'
updated_date: '2026-03-31 19:22'
labels:
  - story
milestone: m-5
dependencies:
  - TASK-32.5
references:
  - webapp/app/api/
documentation:
  - doc-16
parent_task_id: TASK-32
priority: high
ordinal: 5003
---

## Description

<!-- SECTION:DESCRIPTION:BEGIN -->
Create API route handlers for Kafka cluster operations using the App Router pattern. Implement GET handlers for: cluster metadata, topic list, topic detail, consumer groups list, consumer group detail. Each route uses the shared Kafka client module and returns JSON. Dynamic route segments use Promise<{ param }> pattern per Next.js 15. Per doc-16.
<!-- SECTION:DESCRIPTION:END -->

## Acceptance Criteria
<!-- AC:BEGIN -->
- [ ] #1 API route at app/api/cluster/route.ts returns broker list and cluster metadata
- [ ] #2 API route at app/api/topics/route.ts returns topic list with partition counts
- [ ] #3 API route at app/api/topics/[name]/route.ts returns topic detail (partitions, offsets, config)
- [ ] #4 API route at app/api/consumer-groups/route.ts returns consumer group list
- [ ] #5 API route at app/api/consumer-groups/[id]/route.ts returns group detail with member assignments
- [ ] #6 All routes use shared Kafka client module
- [ ] #7 Error responses return proper HTTP status codes and JSON error bodies
<!-- AC:END -->
