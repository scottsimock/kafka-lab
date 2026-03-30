---
id: TASK-31.1
title: SP4.003 — Schema Registry and Connect Group Variables
status: Done
assignee:
  - tester-1
created_date: '2026-03-30 16:45'
updated_date: '2026-03-30 23:38'
labels:
  - story
milestone: m-4
dependencies:
  - TASK-31.3
  - TASK-31.6
references:
  - ansible/inventory/group_vars/
  - ansible/group_vars/schema_registry.yml
  - ansible/group_vars/kafka_connect.yml
  - ansible/group_vars/kafka_broker.yml
  - ansible/roles/kafka-client-creds/defaults/main.yml
documentation:
  - doc-6
  - doc-7
  - doc-13
parent_task_id: TASK-31
priority: medium
ordinal: 4003
---

## Description

<!-- SECTION:DESCRIPTION:BEGIN -->
Populate Ansible group_vars files for Schema Registry and Kafka Connect, overriding role defaults for the kafka-lab environment. These files override the sensible defaults in roles/schema-registry/defaults/ and roles/kafka-connect/defaults/ with environment-specific values.

group_vars/schema_registry.yml: bootstrap servers (kb-01:9092,kb-02:9092,kb-03:9092), security protocol (SASL_SSL), SCRAM credentials (vault references), TLS keystore/truststore paths, JVM heap (512m for dev), schema compatibility level.

group_vars/kafka_connect.yml: bootstrap servers, group.id, SCRAM credentials (vault references), TLS keystore/truststore paths, converter classes (Avro with Schema Registry URL http://sr-01:8081), plugin path, REST API settings, JVM heap (512m for dev).

The dependency on TASK-31.3 and TASK-31.6 is intentional — roles must define their defaults/ variables first so group vars can override the correct variable names for our environment.
<!-- SECTION:DESCRIPTION:END -->

## Acceptance Criteria
<!-- AC:BEGIN -->
- [x] #1 group_vars/schema_registry.yml defines SR-specific variables overriding role defaults
- [x] #2 group_vars/kafka_connect.yml defines Connect-specific variables overriding role defaults
- [x] #3 Variables include bootstrap servers pointing to kb-01:9092, kb-02:9092, kb-03:9092
- [x] #4 SCRAM credential variables reference vault_* password variables (vault_kafka_schema_registry_password, vault_kafka_connect_worker_password)
- [x] #5 TLS keystore/truststore paths and passwords configured following broker group_vars pattern
- [x] #6 SR JVM heap set to 512m for dev via role variable override
- [x] #7 Connect JVM heap set to 512m for dev via role variable override
- [x] #8 Connect converter classes configured for Avro with schema.registry.url=http://sr-01:8081
<!-- AC:END -->

## Implementation Notes

<!-- SECTION:NOTES:BEGIN -->
## [TL] 2026-03-30T23:35:00Z
- Coder-1 completed: populated both group_vars files
- Review: 8/8 AC passed (100%) — manual TL review
- Verdict: PASS
<!-- SECTION:NOTES:END -->
