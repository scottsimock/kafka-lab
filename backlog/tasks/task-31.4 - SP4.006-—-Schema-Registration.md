---
id: TASK-31.4
title: SP4.006 — Schema Registration
status: Done
assignee:
  - tester-1
created_date: '2026-03-30 16:45'
updated_date: '2026-03-30 23:41'
labels:
  - story
milestone: m-4
dependencies:
  - TASK-31.3
  - TASK-31.2
references:
  - ansible/playbooks/
  - ansible/files/schemas/
  - ansible/playbooks/register-schemas.yml
documentation:
  - doc-6
parent_task_id: TASK-31
priority: medium
ordinal: 4006
---

## Description

<!-- SECTION:DESCRIPTION:BEGIN -->
Create and register Avro schemas for application topics with Schema Registry. Define schemas for app-messages (key: string, value: message record with id, content, timestamp, source fields), app-events (event record with event_type, payload, timestamp), app-metrics (metrics record with metric_name, value, unit, timestamp). Store schema .avsc files under ansible/files/schemas/.

Register schemas via SR REST API using Ansible uri module in a dedicated playbook (ansible/playbooks/register-schemas.yml). Set BACKWARD compatibility. Per doc-6, schemas are stored in _schemas topic. Schema Registry must be running (deployed via site.yml) before registration.
<!-- SECTION:DESCRIPTION:END -->

## Acceptance Criteria
<!-- AC:BEGIN -->
- [x] #1 Avro schema .avsc files created under ansible/files/schemas/ for app-messages, app-events, and app-metrics
- [x] #2 Schemas include meaningful fields (not just stubs): message has id/content/timestamp/source, event has event_type/payload/timestamp, metrics has metric_name/value/unit/timestamp
- [x] #3 Ansible playbook ansible/playbooks/register-schemas.yml registers schemas via SR REST API (POST /subjects/{subject}-value/versions)
- [x] #4 Schema compatibility set to BACKWARD for all subjects via PUT /config/{subject}
- [x] #5 Playbook uses ansible.builtin.uri module targeting http://sr-01:8081
- [x] #6 GET /subjects lists all registered subjects after playbook run
<!-- AC:END -->

## Implementation Notes

<!-- SECTION:NOTES:BEGIN -->
## [TL] 2026-03-30T23:41:00Z
- Coder-1 completed: 3 avsc schemas + registration playbook
- Tester-1 review: 6/6 AC passed (100%)
- Verdict: PASS
<!-- SECTION:NOTES:END -->
