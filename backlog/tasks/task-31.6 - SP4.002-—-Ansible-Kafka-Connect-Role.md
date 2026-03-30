---
id: TASK-31.6
title: SP4.002 — Ansible Kafka Connect Role
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
  - ansible/roles/kafka-connect/
documentation:
  - doc-7
  - doc-13
parent_task_id: TASK-31
priority: high
ordinal: 4002
---

## Description

<!-- SECTION:DESCRIPTION:BEGIN -->
Create the Kafka Connect Ansible role at ansible/roles/kafka-connect/. Render connect-distributed.properties with bootstrap servers, group.id, internal topic config (connect-configs, connect-offsets, connect-status), key/value converters, REST API config, and SASL_SSL security. Create systemd unit and health check. Per doc-7, distributed mode stores all state in Kafka topics.
<!-- SECTION:DESCRIPTION:END -->

## Acceptance Criteria
<!-- AC:BEGIN -->
- [ ] #1 Role exists at ansible/roles/kafka-connect/ with tasks/, handlers/, defaults/, templates/
- [ ] #2 Renders connect-distributed.properties from Jinja2 template
- [ ] #3 Configures bootstrap.servers, group.id, internal topic names
- [ ] #4 Internal topics use replication factor 1 for dev
- [ ] #5 SASL_SSL configured for broker communication
- [ ] #6 REST API listener on 0.0.0.0:8083
- [ ] #7 Plugin path includes /usr/share/java and /usr/share/confluent-hub-components
- [ ] #8 Creates systemd unit confluent-kafka-connect.service
- [ ] #9 Health check handler verifies GET / returns version
<!-- AC:END -->
