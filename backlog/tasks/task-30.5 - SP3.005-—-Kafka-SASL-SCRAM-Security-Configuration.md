---
id: TASK-30.5
title: SP3.005 — Kafka SASL/SCRAM Security Configuration
status: To Do
assignee: []
created_date: '2026-03-30 16:44'
updated_date: '2026-03-30 16:44'
labels:
  - story
milestone: m-3
dependencies:
  - TASK-30.7
  - TASK-30.1
references:
  - ansible/roles/kafka-broker/
documentation:
  - doc-11
parent_task_id: TASK-30
priority: high
ordinal: 3005
---

## Description

<!-- SECTION:DESCRIPTION:BEGIN -->
Extend the kafka-broker role to configure SASL/SCRAM-SHA-512 authentication with SASL_SSL transport. Update server.properties template with dual listeners (CLIENT:SASL_SSL on 9092, INTERNAL:SASL_SSL on 9093), SCRAM-SHA-512 mechanism, SSL keystore/truststore configuration, and JAAS credentials. Create bootstrap SCRAM credentials for broker-internal and admin users. Per doc-11, this is the recommended auth model for kafka-lab.
<!-- SECTION:DESCRIPTION:END -->

## Acceptance Criteria
<!-- AC:BEGIN -->
- [ ] #1 Broker server.properties updated with SASL_SSL listeners on ports 9092 (client) and 9093 (inter-broker)
- [ ] #2 listener.security.protocol.map configured for INTERNAL:SASL_SSL and CLIENT:SASL_SSL
- [ ] #3 SCRAM-SHA-512 configured as the SASL mechanism
- [ ] #4 SSL keystore and truststore paths configured
- [ ] #5 Inter-broker authentication uses SCRAM-SHA-512
- [ ] #6 Bootstrap SCRAM credentials created for broker-internal and admin users
- [ ] #7 JAAS configuration rendered from template with credentials from Key Vault
- [ ] #8 Broker restarts successfully with SASL_SSL enabled
<!-- AC:END -->
