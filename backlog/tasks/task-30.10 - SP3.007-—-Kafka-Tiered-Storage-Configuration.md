---
id: TASK-30.10
title: SP3.007 — Kafka Tiered Storage Configuration
status: To Do
assignee: []
created_date: '2026-03-30 16:44'
updated_date: '2026-03-30 22:23'
labels:
  - story
milestone: m-3
dependencies:
  - TASK-30.1
references:
  - ansible/roles/kafka-broker/
documentation:
  - doc-8
parent_task_id: TASK-30
priority: medium
ordinal: 3007
---

## Description

<!-- SECTION:DESCRIPTION:BEGIN -->
Configure Confluent Tiered Storage on Kafka brokers to offload warm log segments to Azure Blob Storage. Add tiered storage properties to the broker server.properties template: enable tier feature, configure Azure Blob Storage backend with the storage account from SP1.011, set hotset retention period. Per doc-8, tiered storage uses a single log.dirs path (no JBOD). Authentication uses UAMI.
<!-- SECTION:DESCRIPTION:END -->

## Acceptance Criteria
<!-- AC:BEGIN -->
- [ ] #1 Tiered storage properties added to server.properties template
- [ ] #2 confluent.tier.feature=true and confluent.tier.enable=true set
- [ ] #3 Azure Blob Storage configured as remote storage backend
- [ ] #4 Storage account credentials reference UAMI authentication
- [ ] #5 confluent.tier.local.hotset.ms configurable (default 24h)
- [ ] #6 Broker restarts with tiered storage enabled
- [ ] #7 Verification: topic with remote storage shows segments offloading
- [ ] #8 Tiered storage configuration guarded by kafka_broker_tiered_storage_enabled boolean
- [ ] #9 confluent.tier.metadata.replication.factor set to 3
<!-- AC:END -->

## Implementation Plan

<!-- SECTION:PLAN:BEGIN -->
## Implementation Plan

### Step 1: Add tiered storage defaults to kafka-broker role

Add to `ansible/roles/kafka-broker/defaults/main.yml`:

```yaml
# Tiered Storage configuration
kafka_broker_tiered_storage_enabled: false
kafka_broker_tier_backend: AzureBlockBlob
kafka_broker_tier_azure_container: klc-kafka-tiered-storage
kafka_broker_tier_azure_credentials_provider: 'com.microsoft.azure.storage.auth.ManagedIdentityCredentialProvider'
kafka_broker_tier_metadata_replication_factor: 3
kafka_broker_tier_local_hotset_ms: 86400000
kafka_broker_tier_archiver_num_threads: 8
kafka_broker_tier_fetcher_num_threads: 8
```

### Step 2: Update server.properties.j2 template

Add a conditional tiered storage block to the existing `server.properties.j2` template:

```properties
{% if kafka_broker_tiered_storage_enabled | default(false) %}
# Tiered Storage — Azure Blob Storage backend
confluent.tier.feature=true
confluent.tier.enable=true
confluent.tier.backend={{ kafka_broker_tier_backend }}
confluent.tier.azure.block.blob.container={{ kafka_broker_tier_azure_container }}
confluent.tier.azure.block.blob.credentials.provider={{ kafka_broker_tier_azure_credentials_provider }}
confluent.tier.metadata.replication.factor={{ kafka_broker_tier_metadata_replication_factor }}
confluent.tier.local.hotset.ms={{ kafka_broker_tier_local_hotset_ms }}
confluent.tier.archiver.num.threads={{ kafka_broker_tier_archiver_num_threads }}
confluent.tier.fetcher.num.threads={{ kafka_broker_tier_fetcher_num_threads }}
{% endif %}
```

Place this block at the end of the server.properties.j2 template, after the core broker config and any SASL/SSL blocks.

### Step 3: Enable in group_vars/kafka_broker.yml

Add to `ansible/group_vars/kafka_broker.yml`:

```yaml
kafka_broker_tiered_storage_enabled: true
```

### Step 4: Verify UAMI credential provider

The `ManagedIdentityCredentialProvider` uses Azure IMDS on the broker VM. No credential file is needed when the VM has a UAMI attached (which it does per SP1 Terraform). If the VM has multiple UAMIs, an optional credential file with `azureClientId` can disambiguate:

```yaml
# Optional: only if multiple UAMIs on broker VMs
kafka_broker_tier_azure_cred_file_path: ''
```

If set, add to template:
```properties
confluent.tier.azure.block.blob.cred.file.path={{ kafka_broker_tier_azure_cred_file_path }}
```

### Step 5: Verify single log.dirs

Per doc-8, tiered storage does NOT support JBOD (multiple log.dirs). Verify that `kafka_broker_log_dirs` is a single path (`/data/kafka/logs`), not a comma-separated list. The default from SP3.002 already uses a single path.

### Step 6: Add verification guidance in notes

After deployment, verification can be done by:
1. Creating a test topic with `confluent.tier.enable=true`
2. Producing enough data to trigger segment roll
3. Checking `kafka-log-dirs` output to see segment offloading

### Key References
- Storage account: klc-kafka-tiered-storage (from SP1.011 Terraform)
- Authentication: UAMI via Azure IMDS (ManagedIdentityCredentialProvider)
- Single log.dirs required (no JBOD)
- Local hotset: 86400000 ms (24 hours) for dev
- Metadata replication factor: 3 (matches cluster replication)
- doc-8: Tiered Storage with Azure Blob section
<!-- SECTION:PLAN:END -->

## Implementation Notes

<!-- SECTION:NOTES:BEGIN -->
## [SM] 2026-03-31T00:00:00Z
- **File contention**: server.properties.j2 and group_vars/kafka_broker.yml are also modified by SP3.005 and SP3.008. TL must serialize template edits for server.properties.j2 (recommend order: SP3.005 → SP3.007 → SP3.008).
- defaults/main.yml (kafka-broker role) is also extended by SP3.005 and SP3.008.
<!-- SECTION:NOTES:END -->
