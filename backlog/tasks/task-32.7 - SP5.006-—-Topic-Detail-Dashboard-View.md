---
id: TASK-32.7
title: SP5.006 — Topic Detail Dashboard View
status: To Do
assignee: []
created_date: '2026-03-30 16:46'
updated_date: '2026-03-30 16:47'
labels:
  - story
milestone: m-5
dependencies:
  - TASK-32.1
references:
  - webapp/app/dashboard/(views)/topics/
documentation:
  - doc-16
parent_task_id: TASK-32
priority: medium
ordinal: 5006
---

## Description

<!-- SECTION:DESCRIPTION:BEGIN -->
Create the Topic Detail dashboard view with list and detail pages. List page at app/dashboard/(views)/topics/page.tsx displays all topics with partition count and RF. Detail page at app/dashboard/(views)/topics/[name]/page.tsx shows per-partition info (leader, replicas, ISR, offsets, config). Both are Server Components. Per doc-16.
<!-- SECTION:DESCRIPTION:END -->

## Acceptance Criteria
<!-- AC:BEGIN -->
- [ ] #1 Topic list page at app/dashboard/(views)/topics/page.tsx shows all topics
- [ ] #2 Topic detail page at app/dashboard/(views)/topics/[name]/page.tsx shows partitions, offsets, config
- [ ] #3 Topic list includes partition count, replication factor, message count per topic
- [ ] #4 Topic detail shows per-partition leader, replicas, ISR
- [ ] #5 Both pages are Server Components with loading/error boundaries
<!-- AC:END -->
