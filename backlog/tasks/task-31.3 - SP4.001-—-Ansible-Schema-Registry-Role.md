---
id: TASK-31.3
title: SP4.001 — Ansible Schema Registry Role
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
  - ansible/roles/schema-registry/
documentation:
  - doc-6
  - doc-13
parent_task_id: TASK-31
priority: high
ordinal: 4001
---

## Description

<!-- SECTION:DESCRIPTION:BEGIN -->
Create the Schema Registry Ansible role at ansible/roles/schema-registry/. Render schema-registry.properties with Kafka bootstrap servers, SASL_SSL security, listener config, schema compatibility level (BACKWARD default). Create systemd unit and health check handler. Per doc-6, SR stores data in _schemas topic, is stateless on disk.
<!-- SECTION:DESCRIPTION:END -->

## Acceptance Criteria
<!-- AC:BEGIN -->
- [ ] #1 Role exists at ansible/roles/schema-registry/ with tasks/, handlers/, defaults/, templates/
- [ ] #2 Renders schema-registry.properties from Jinja2 template
- [ ] #3 Configures kafkastore.bootstrap.servers pointing to broker cluster
- [ ] #4 Sets kafkastore.topic.replication.factor=1 for dev (3 for prod)
- [ ] #5 Configures SASL_SSL for broker communication
- [ ] #6 Configures listener on http://0.0.0.0:8081
- [ ] #7 Creates systemd unit confluent-schema-registry.service
- [ ] #8 Health check handler verifies GET /subjects returns 200
<!-- AC:END -->
