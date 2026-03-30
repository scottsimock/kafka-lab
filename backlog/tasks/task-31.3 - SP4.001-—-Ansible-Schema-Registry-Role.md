---
id: TASK-31.3
title: SP4.001 — Ansible Schema Registry Role
status: Done
assignee:
  - tester-1
created_date: '2026-03-30 16:45'
updated_date: '2026-03-30 23:28'
labels:
  - story
milestone: m-4
dependencies:
  - TASK-30.2
references:
  - ansible/roles/schema-registry/
  - ansible/site.yml
  - ansible/roles/kafka-broker/defaults/main.yml
  - ansible/roles/kafka-broker/templates/server.properties.j2
documentation:
  - doc-6
  - doc-13
parent_task_id: TASK-31
priority: high
ordinal: 4001
---

## Description

<!-- SECTION:DESCRIPTION:BEGIN -->
Create the Schema Registry Ansible role at ansible/roles/schema-registry/. Render schema-registry.properties with Kafka bootstrap servers, SASL_SSL security (SCRAM-SHA-512 JAAS config following the kafka-broker role pattern), listener config, schema compatibility level (BACKWARD default). Create systemd unit with JVM heap via environment file and health check handler. Per doc-6, SR stores data in _schemas topic, is stateless on disk.

Implementation context:
- Follow the kafka-broker role structure: defaults/main.yml, tasks/{main,configure,service}.yml, handlers/main.yml, templates/*.j2
- SCRAM credentials for schema-registry user already created in SP3 (kafka-client-creds role)
- TLS keystores/truststores follow the broker pattern: JKS files in ssl_dir, passwords from vault_* variables
- site.yml Play 3 already exists with common, java, confluent-common — add schema-registry role after confluent-common
- The tls-certs role must be added to Play 3 before schema-registry so keystores are provisioned on the SR VM
- Confluent Platform 7.9, install via confluent-common package (confluent-schema-registry)
<!-- SECTION:DESCRIPTION:END -->

## Acceptance Criteria
<!-- AC:BEGIN -->
- [x] #1 Role exists at ansible/roles/schema-registry/ with tasks/, handlers/, defaults/, templates/
- [x] #2 Renders schema-registry.properties from Jinja2 template
- [x] #3 Configures kafkastore.bootstrap.servers pointing to broker cluster
- [x] #4 Sets kafkastore.topic.replication.factor via variable (default 3 for 3-broker cluster)
- [x] #5 Configures SASL_SSL for broker communication with SCRAM-SHA-512 JAAS config
- [x] #6 Configures listener on http://0.0.0.0:8081
- [x] #7 Creates systemd unit confluent-schema-registry.service with JVM heap settings via environment file
- [x] #8 Health check handler verifies GET /subjects returns 200
- [x] #9 site.yml Play 3 updated to include tls-certs and schema-registry roles
- [x] #10 TLS keystore/truststore paths configured for SASL_SSL broker communication following broker pattern
<!-- AC:END -->

## Implementation Notes

<!-- SECTION:NOTES:BEGIN -->
## [TL] 2026-03-30T23:27:00Z
- Coder-1 completed: 10 files across 4 directories
- Tester-1 review: 10/10 AC passed (100%)
- Verdict: PASS
<!-- SECTION:NOTES:END -->
