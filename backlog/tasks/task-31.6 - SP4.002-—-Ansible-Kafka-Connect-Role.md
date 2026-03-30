---
id: TASK-31.6
title: SP4.002 — Ansible Kafka Connect Role
status: Done
assignee:
  - tester-2
created_date: '2026-03-30 16:45'
updated_date: '2026-03-30 23:28'
labels:
  - story
milestone: m-4
dependencies:
  - TASK-30.2
references:
  - ansible/roles/kafka-connect/
  - ansible/site.yml
  - ansible/roles/kafka-broker/defaults/main.yml
  - ansible/roles/kafka-broker/templates/server.properties.j2
documentation:
  - doc-7
  - doc-13
parent_task_id: TASK-31
priority: high
ordinal: 4002
---

## Description

<!-- SECTION:DESCRIPTION:BEGIN -->
Create the Kafka Connect Ansible role at ansible/roles/kafka-connect/. Render connect-distributed.properties with bootstrap servers, group.id, internal topic config (connect-configs, connect-offsets, connect-status), key/value converters (Avro with Schema Registry URL), REST API config, SASL_SSL security (SCRAM-SHA-512), and producer/consumer override configs. Create systemd unit with JVM heap via environment file and health check. Per doc-7, distributed mode stores all state in Kafka topics.

Implementation context:
- Follow the kafka-broker role structure: defaults/main.yml, tasks/{main,configure,service}.yml, handlers/main.yml, templates/*.j2
- SCRAM credentials for connect-worker user already created in SP3 (kafka-client-creds role)
- TLS keystores/truststores follow the broker pattern: JKS files in ssl_dir, passwords from vault_* variables
- site.yml Play 4 already exists with common, java, confluent-common — add kafka-connect role after confluent-common
- The tls-certs role must be added to Play 4 before kafka-connect so keystores are provisioned on the Connect VM
- Connect needs both broker security config AND producer/consumer override security for connector tasks
- Confluent Platform 7.9, install via confluent-common package (confluent-kafka-connect)
<!-- SECTION:DESCRIPTION:END -->

## Acceptance Criteria
<!-- AC:BEGIN -->
- [x] #1 Role exists at ansible/roles/kafka-connect/ with tasks/, handlers/, defaults/, templates/
- [x] #2 Renders connect-distributed.properties from Jinja2 template
- [x] #3 Configures bootstrap.servers, group.id, internal topic names
- [x] #4 Internal topics use replication factor via variable (default 3 for 3-broker cluster)
- [x] #5 SASL_SSL configured for broker communication with SCRAM-SHA-512 JAAS config
- [x] #6 REST API listener on 0.0.0.0:8083
- [x] #7 Plugin path includes /usr/share/java and /usr/share/confluent-hub-components
- [x] #8 Creates systemd unit confluent-kafka-connect.service with JVM heap settings via environment file
- [x] #9 Health check handler verifies GET / returns version info
- [x] #10 Key and value converters set to Avro with schema.registry.url configured
- [x] #11 Producer and consumer override configs include SASL_SSL security settings
- [x] #12 site.yml Play 4 updated to include tls-certs and kafka-connect roles
<!-- AC:END -->

## Implementation Notes

<!-- SECTION:NOTES:BEGIN -->
## [TL] 2026-03-30T23:27:00Z
- Coder-2 completed: 9 files across 4 directories
- Tester-2 review: 12/12 AC passed (100%)
- Verdict: PASS
<!-- SECTION:NOTES:END -->
