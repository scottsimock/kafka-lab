---
id: TASK-31.2
title: SP4.005 — Application Topic Creation
status: To Do
assignee: []
created_date: '2026-03-30 16:45'
updated_date: '2026-03-30 16:45'
labels:
  - story
milestone: m-4
dependencies:
  - TASK-30.2
references:
  - ansible/playbooks/
documentation:
  - doc-8
parent_task_id: TASK-31
priority: medium
ordinal: 4005
---

## Description

<!-- SECTION:DESCRIPTION:BEGIN -->
Create application-specific Kafka topics for the web application. Define topics: app-messages (12 partitions, RF=3), app-events (6 partitions, RF=3), app-metrics (6 partitions, RF=3), and app-state (compacted, 6 partitions, RF=3). Set min.insync.replicas=2 on all topics. Create via Ansible task using kafka-topics CLI.
<!-- SECTION:DESCRIPTION:END -->

## Acceptance Criteria
<!-- AC:BEGIN -->
- [ ] #1 Ansible playbook or task creates application topics with correct RF and partition counts
- [ ] #2 Topics created: app-messages (RF=3, 12 partitions), app-events (RF=3, 6 partitions), app-metrics (RF=3, 6 partitions)
- [ ] #3 Compacted topic created: app-state (RF=3, 6 partitions, cleanup.policy=compact)
- [ ] #4 All topics have min.insync.replicas=2
- [ ] #5 kafka-topics --list shows all expected topics
<!-- AC:END -->
