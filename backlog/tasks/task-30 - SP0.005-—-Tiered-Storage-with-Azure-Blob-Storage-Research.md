---
id: TASK-30
title: SP0.005 — Tiered Storage with Azure Blob Storage Research
status: To Do
assignee: []
created_date: '2026-03-30 13:42'
updated_date: '2026-03-30 13:48'
labels:
  - research
milestone: m-0
dependencies: []
references:
  - 'https://docs.confluent.io/platform/current/kafka/tiered-storage.html'
  - 'https://learn.microsoft.com/en-us/azure/storage/blobs/storage-blobs-overview'
  - >-
    https://learn.microsoft.com/en-us/azure/storage/common/storage-private-endpoints
priority: medium
ordinal: 5000
---

## Description

<!-- SECTION:DESCRIPTION:BEGIN -->
Research Confluent tiered storage configuration with Azure Blob Storage backend. Cover storage integration, private endpoint access, CMEK encryption, and retention policies.\n\nKey areas:\n- Confluent tiered storage architecture and how it integrates with Kafka brokers\n- Azure Blob Storage configuration as tiered storage backend\n- Private endpoint access for Blob Storage (no public endpoint per project requirements)\n- Customer Managed Key (CMEK) encryption for data at rest\n- Retention policies: local vs remote retention, compaction behavior\n- Performance implications of tiered storage reads\n- Broker configuration properties for tiered storage enablement\n- Storage account sizing and throughput requirements for dev environment\n\nExpected output: backlog document doc-SP0.005-tiered-storage-azure-blob
<!-- SECTION:DESCRIPTION:END -->

## Acceptance Criteria
<!-- AC:BEGIN -->
- [ ] #1 Confluent tiered storage architecture explained with broker integration points
- [ ] #2 Azure Blob Storage configuration for tiered storage backend documented
- [ ] #3 Private endpoint configuration for Blob Storage documented
- [ ] #4 CMEK encryption setup for Blob Storage documented
- [ ] #5 Local and remote retention policy configuration documented
- [ ] #6 Broker properties for tiered storage enablement listed with recommended values
- [ ] #7 Storage account sizing estimated for dev environment
- [ ] #8 All findings reference official Confluent and Azure documentation
<!-- AC:END -->
