---
id: TASK-31.4
title: SP4.006 — Schema Registration
status: To Do
assignee: []
created_date: '2026-03-30 16:45'
updated_date: '2026-03-30 16:45'
labels:
  - story
milestone: m-4
dependencies:
  - TASK-31.3
  - TASK-31.2
references:
  - ansible/playbooks/
documentation:
  - doc-6
parent_task_id: TASK-31
priority: medium
ordinal: 4006
---

## Description

<!-- SECTION:DESCRIPTION:BEGIN -->
Create and register Avro schemas for application topics with Schema Registry. Define schemas for app-messages (key: string, value: message record), app-events (event record), app-metrics (metrics record). Register via SR REST API. Set BACKWARD compatibility. Per doc-6, schemas are stored in _schemas topic.
<!-- SECTION:DESCRIPTION:END -->

## Acceptance Criteria
<!-- AC:BEGIN -->
- [ ] #1 Avro schema files created for app-messages, app-events, and app-metrics topics
- [ ] #2 Schemas registered via Schema Registry REST API (POST /subjects/{subject}/versions)
- [ ] #3 Schema compatibility set to BACKWARD for all subjects
- [ ] #4 Schema IDs returned and documented
- [ ] #5 GET /subjects lists all registered subjects
<!-- AC:END -->
