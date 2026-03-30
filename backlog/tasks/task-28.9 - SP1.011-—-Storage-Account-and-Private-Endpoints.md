---
id: TASK-28.9
title: SP1.011 — Storage Account and Private Endpoints
status: To Do
assignee: []
created_date: '2026-03-30 16:40'
updated_date: '2026-03-30 16:40'
labels:
  - story
milestone: m-1
dependencies:
  - TASK-28.4
  - TASK-28.7
  - TASK-28.11
references:
  - terraform/modules/private-endpoint/
documentation:
  - doc-10
  - doc-14
parent_task_id: TASK-28
priority: medium
ordinal: 1011
---

## Description

<!-- SECTION:DESCRIPTION:BEGIN -->
Create private endpoints for Key Vault (from SP1.004) and provision a Storage Account for Terraform state with CMEK encryption, private endpoint access only. The storage account uses azapi_resource with type Microsoft.Storage/storageAccounts, CMEK from Key Vault, UAMI identity, TLS 1.2 minimum, public access disabled, and a blob container for Terraform state. Create private endpoints for both Key Vault (group_id: vault) and Storage Account (group_id: blob) using the private endpoint module.
<!-- SECTION:DESCRIPTION:END -->

## Acceptance Criteria
<!-- AC:BEGIN -->
- [ ] #1 Storage account provisioned with azapi_resource Microsoft.Storage/storageAccounts
- [ ] #2 CMEK encryption configured using Key Vault key from SP1.004
- [ ] #3 public_network_access disabled
- [ ] #4 minimum TLS 1.2 enforced
- [ ] #5 UAMI assigned to storage account
- [ ] #6 Private endpoint created in snet-private-endpoints subnet
- [ ] #7 Private DNS A record registered in privatelink.blob.core.windows.net zone
- [ ] #8 Key Vault private endpoint created and DNS registered
- [ ] #9 terraform validate passes
<!-- AC:END -->
