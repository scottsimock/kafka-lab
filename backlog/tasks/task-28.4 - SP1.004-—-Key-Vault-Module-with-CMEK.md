---
id: TASK-28.4
title: SP1.004 — Key Vault Module with CMEK
status: To Do
assignee: []
created_date: '2026-03-30 16:38'
updated_date: '2026-03-30 16:40'
labels:
  - story
milestone: m-1
dependencies:
  - TASK-28.3
references:
  - terraform/modules/key-vault/
documentation:
  - doc-14
parent_task_id: TASK-28
priority: high
ordinal: 1004
---

## Description

<!-- SECTION:DESCRIPTION:BEGIN -->
Create a reusable Terraform module at terraform/modules/key-vault/ that provisions Azure Key Vault with CMEK support using azapi_resource. The Key Vault must have purge protection enabled, soft delete with 90 day retention, public network access disabled, and TLS 1.2 minimum. Create an encryption key within the vault for use by other resources. Accept uami_id as input to grant key management permissions. Output key_vault_id, key_vault_uri, and cmk_key_id.
<!-- SECTION:DESCRIPTION:END -->

## Acceptance Criteria
<!-- AC:BEGIN -->
- [ ] #1 Module exists at terraform/modules/key-vault/
- [ ] #2 Uses azapi_resource with Microsoft.KeyVault/vaults
- [ ] #3 Enables purge protection and soft delete
- [ ] #4 Configures CMEK encryption key via azapi_resource Microsoft.KeyVault/vaults/keys
- [ ] #5 Access policy grants UAMI key wrap/unwrap permissions
- [ ] #6 public_network_access set to Disabled
- [ ] #7 Outputs key_vault_id, key_vault_uri, cmk_key_id
- [ ] #8 terraform validate passes
<!-- AC:END -->
