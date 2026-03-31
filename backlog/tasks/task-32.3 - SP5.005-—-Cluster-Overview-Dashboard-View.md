---
id: TASK-32.3
title: SP5.005 — Cluster Overview Dashboard View
status: In Progress
assignee:
  - Dallas
created_date: '2026-03-30 16:46'
updated_date: '2026-03-31 19:23'
labels:
  - story
milestone: m-5
dependencies:
  - TASK-32.1
references:
  - webapp/app/dashboard/(views)/overview/
documentation:
  - doc-16
parent_task_id: TASK-32
priority: medium
ordinal: 5005
---

## Description

<!-- SECTION:DESCRIPTION:BEGIN -->
Create the Cluster Overview dashboard view as a Server Component at app/dashboard/(views)/overview/page.tsx. Display broker status (online/offline), total partition count, under-replicated partition count, and overall cluster health indicator. Fetch data from the /api/cluster endpoint. Include loading.tsx and error.tsx boundaries. Per doc-16.
<!-- SECTION:DESCRIPTION:END -->

## Acceptance Criteria
<!-- AC:BEGIN -->
- [ ] #1 Server Component at app/dashboard/(views)/overview/page.tsx
- [ ] #2 Displays broker count, partition distribution, under-replicated partitions
- [ ] #3 Shows cluster health status (healthy/degraded/unhealthy)
- [ ] #4 Fetches data from /api/cluster endpoint
- [ ] #5 Includes loading.tsx Suspense fallback
- [ ] #6 Includes error.tsx error boundary
<!-- AC:END -->
