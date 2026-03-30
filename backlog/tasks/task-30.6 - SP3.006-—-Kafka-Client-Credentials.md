---
id: TASK-30.6
title: SP3.006 — Kafka Client Credentials
status: To Do
assignee: []
created_date: '2026-03-30 16:44'
updated_date: '2026-03-30 16:44'
labels:
  - story
milestone: m-3
dependencies:
  - TASK-30.5
references:
  - ansible/roles/kafka-broker/
documentation:
  - doc-11
parent_task_id: TASK-30
priority: medium
ordinal: 3006
---

## Description

<!-- SECTION:DESCRIPTION:BEGIN -->
Create SCRAM-SHA-512 credentials for all Kafka client services: web-app (Next.js), schema-registry, connect-worker, and admin user. Generate client.properties files for each service containing SASL_SSL configuration, JAAS credentials, and truststore references. Store sensitive credentials in Ansible vault. This task configures the client side of the SASL/SCRAM setup from SP3.005.
<!-- SECTION:DESCRIPTION:END -->

## Acceptance Criteria
<!-- AC:BEGIN -->
- [ ] #1 SCRAM credentials created for web-app, schema-registry, and connect-worker users
- [ ] #2 client.properties files generated for each service with SASL_SSL config
- [ ] #3 admin.properties file created for administrative operations
- [ ] #4 Credentials stored in Ansible vault or referenced from Key Vault
- [ ] #5 kafka-configs --describe verifies credentials exist for all users
<!-- AC:END -->
