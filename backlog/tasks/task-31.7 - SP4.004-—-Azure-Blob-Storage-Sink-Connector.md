---
id: TASK-31.7
title: SP4.004 — Azure Blob Storage Sink Connector
status: Done
assignee:
  - tester-2
created_date: '2026-03-30 16:45'
updated_date: '2026-03-30 23:38'
labels:
  - story
milestone: m-4
dependencies:
  - TASK-31.6
references:
  - ansible/roles/kafka-connect/
  - terraform/environments/dev/main.tf
  - terraform/environments/dev/outputs.tf
documentation:
  - doc-7
parent_task_id: TASK-31
priority: medium
ordinal: 4004
---

## Description

<!-- SECTION:DESCRIPTION:BEGIN -->
Install and configure the Azure Blob Storage Sink Connector for Kafka Connect. Install via confluent-hub CLI as an Ansible task within or alongside the kafka-connect role. Create a connector configuration JSON file that sinks data from application topics (app-messages, app-events, app-metrics) to Azure Blob Storage using Avro format.

Configure UAMI-based authentication (no storage keys) using the existing Terraform UAMI (klc-id-kafkalab-scus). The Terraform storage account klcstgkafkalabscus already exists with private endpoint access. A new blob container for sink data may need to be provisioned or the task should create one via the connector config.

Configure DLQ for error handling and flush.size for batching. Per doc-7, connectors are managed via REST API — the config file is deployed via REST in the verification playbook (TASK-31.5).
<!-- SECTION:DESCRIPTION:END -->

## Acceptance Criteria
<!-- AC:BEGIN -->
- [x] #1 Ansible task installs Azure Blob Storage Sink Connector via confluent-hub install
- [x] #2 Connector JAR placed in plugin.path directory (/usr/share/confluent-hub-components)
- [x] #3 Connector configuration JSON file created for Azure Blob sink
- [x] #4 Configuration specifies topics: app-messages, app-events, app-metrics
- [x] #5 Configuration includes storage account (klcstgkafkalabscus), container name, format (Avro), flush.size
- [x] #6 Authentication uses UAMI via com.microsoft.azure.storage.auth.ManagedIdentityCredentialProvider (no storage account keys)
- [x] #7 Dead Letter Queue (DLQ) topic configured with name and replication factor for error handling
- [x] #8 Connector config stored as Ansible template at ansible/roles/kafka-connect/templates/ or ansible/files/
<!-- AC:END -->

## Implementation Notes

<!-- SECTION:NOTES:BEGIN -->
## [Tester-2] 2026-03-31T00:15:00Z
- Reviewed connector-install.yml, azure-blob-sink-connector.json.j2, defaults/main.yml, main.yml, handlers/main.yml
- All 8 AC verified PASS — score 8/8 (100%)
- FQCN used (ansible.builtin.command), creates: guard for idempotency, handler chains to health check
- UAMI auth confirmed via ManagedIdentityCredentialProvider, no storage keys present
- DLQ configured with topic name and replication factor
- VERDICT: PASS

## [TL] 2026-03-30T23:35:00Z
- Coder-2 completed: connector install task, JSON template, defaults
- Tester-2 review: 8/8 AC passed (100%)
- Verdict: PASS
<!-- SECTION:NOTES:END -->
