---
id: TASK-32.9
title: SP5.008 — Message Browser Dashboard View
status: To Do
assignee: []
created_date: '2026-03-30 16:46'
updated_date: '2026-03-30 16:47'
labels:
  - story
milestone: m-5
dependencies:
  - TASK-32.6
references:
  - webapp/app/dashboard/(views)/messages/
documentation:
  - doc-16
parent_task_id: TASK-32
priority: medium
ordinal: 5008
---

## Description

<!-- SECTION:DESCRIPTION:BEGIN -->
Create the Message Browser dashboard view as primarily a Client Component at app/dashboard/(views)/messages/page.tsx. Include a produce form (topic, key, value) and a consume display. Implement real-time message streaming via SSE from /api/messages/stream. Display messages with key, value, partition, offset, and timestamp. Support schema-aware deserialization. Per doc-16.
<!-- SECTION:DESCRIPTION:END -->

## Acceptance Criteria
<!-- AC:BEGIN -->
- [ ] #1 Message Browser at app/dashboard/(views)/messages/page.tsx
- [ ] #2 Client Component with topic selector, partition selector, and offset input
- [ ] #3 Produce form: topic, key, value fields with submit button
- [ ] #4 Consume display: shows messages with key, value, partition, offset, timestamp
- [ ] #5 Real-time streaming via SSE connection to /api/messages/stream
- [ ] #6 Schema-aware display: shows deserialized Avro values when schema is available
<!-- AC:END -->
