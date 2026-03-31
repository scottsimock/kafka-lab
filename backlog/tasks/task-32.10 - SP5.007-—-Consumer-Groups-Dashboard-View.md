---
id: TASK-32.10
title: SP5.007 — Consumer Groups Dashboard View
status: Done
assignee:
  - Drexl
created_date: '2026-03-30 16:46'
updated_date: '2026-03-31 19:56'
labels:
  - story
milestone: m-5
dependencies:
  - TASK-32.1
references:
  - webapp/app/dashboard/(views)/consumer-groups/
documentation:
  - doc-16
parent_task_id: TASK-32
priority: medium
ordinal: 5007
---

## Description

<!-- SECTION:DESCRIPTION:BEGIN -->
Create the Consumer Groups dashboard view with list and detail pages. List page shows consumer group ID, state, and member count. Detail page shows per-partition consumer lag, member assignments, and committed offsets. Include a Client Component RefreshButton for manual refresh. Per doc-16.
<!-- SECTION:DESCRIPTION:END -->

## Acceptance Criteria
<!-- AC:BEGIN -->
- [ ] #1 Consumer Groups page at app/dashboard/(views)/consumer-groups/page.tsx lists all groups
- [ ] #2 Detail page at app/dashboard/(views)/consumer-groups/[id]/page.tsx shows members and lag
- [ ] #3 Group list shows group ID, state (Stable/Rebalancing/Empty), member count
- [ ] #4 Detail page shows per-partition lag, member assignments, committed offsets
- [ ] #5 Client Component RefreshButton for manual data refresh
<!-- AC:END -->
