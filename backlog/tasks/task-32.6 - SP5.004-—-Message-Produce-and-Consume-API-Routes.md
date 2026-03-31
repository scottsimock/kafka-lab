---
id: TASK-32.6
title: SP5.004 — Message Produce and Consume API Routes
status: In Progress
assignee:
  - Dallas
created_date: '2026-03-30 16:46'
updated_date: '2026-03-31 19:12'
labels:
  - story
milestone: m-5
dependencies:
  - TASK-32.5
references:
  - webapp/app/api/messages/
documentation:
  - doc-16
parent_task_id: TASK-32
priority: high
ordinal: 5004
---

## Description

<!-- SECTION:DESCRIPTION:BEGIN -->
Create API route handlers for message production and consumption. POST /api/messages/produce: produce messages to a topic with key, value, headers. GET /api/messages/consume: consume messages from a topic/partition/offset. GET /api/messages/stream: SSE endpoint that streams messages in real-time using ReadableStream. Per doc-16.
<!-- SECTION:DESCRIPTION:END -->

## Acceptance Criteria
<!-- AC:BEGIN -->
- [ ] #1 API route at app/api/messages/produce/route.ts accepts POST with topic, key, value, headers
- [ ] #2 API route at app/api/messages/consume/route.ts accepts GET with topic, partition, offset params
- [ ] #3 API route at app/api/messages/stream/route.ts returns Server-Sent Events stream
- [ ] #4 Produce endpoint validates input and returns partition/offset of produced message
- [ ] #5 Consume endpoint returns array of messages with deserialized values
- [ ] #6 Stream endpoint uses ReadableStream for real-time message delivery
<!-- AC:END -->
