---
id: TASK-30.7
title: SP3.004 — TLS Certificate Generation Role
status: To Do
assignee: []
created_date: '2026-03-30 16:44'
updated_date: '2026-03-30 16:44'
labels:
  - story
milestone: m-3
dependencies:
  - TASK-30.1
references:
  - ansible/roles/tls-certs/
documentation:
  - doc-11
parent_task_id: TASK-30
priority: high
ordinal: 3004
---

## Description

<!-- SECTION:DESCRIPTION:BEGIN -->
Create an Ansible role at ansible/roles/tls-certs/ that generates TLS certificates for Kafka cluster security. Generate a private CA, then per-node server certificates signed by the CA. Create JKS keystores and truststores. The role runs on the Ansible controller and distributes certificates to target nodes. Certificates include SAN entries for private IPs. Per doc-11, all Kafka components need TLS for SASL_SSL protocol.
<!-- SECTION:DESCRIPTION:END -->

## Acceptance Criteria
<!-- AC:BEGIN -->
- [ ] #1 Role exists at ansible/roles/tls-certs/ with tasks/, templates/, files/ directories
- [ ] #2 Generates a private CA key and self-signed CA certificate
- [ ] #3 Generates per-node server certificates signed by the CA
- [ ] #4 Creates JKS keystores and truststores for each Kafka component
- [ ] #5 Stores CA cert in a shared truststore
- [ ] #6 Certificates use SAN entries with private IPs and hostnames
- [ ] #7 All key material placed in /etc/kafka/ssl/ on target nodes
<!-- AC:END -->
