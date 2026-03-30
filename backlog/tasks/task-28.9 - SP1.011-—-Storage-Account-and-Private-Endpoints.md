---
id: TASK-28.9
title: SP1.011 — Storage Account and Private Endpoints
status: In Progress
assignee:
  - coder-1
created_date: '2026-03-30 16:40'
updated_date: '2026-03-30 19:41'
labels:
  - story
milestone: m-1
dependencies:
  - TASK-28.3
  - TASK-28.4
  - TASK-28.5
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
Provision a Storage Account for Terraform state with CMEK encryption and create private endpoints for both the Storage Account and Key Vault (from TASK-28.4). This is the integration task that ties together UAMI, Key Vault, VNet, DNS zones, and private endpoints.

**Storage Account** (azapi_resource, Microsoft.Storage/storageAccounts@2023-01-01):
- Name: klcstgkafkalabscus (no hyphens — storage account names must be 3-24 lowercase alphanumeric only)
- Kind: StorageV2, SKU: Standard_LRS
- CMEK encryption using the Key Vault key from TASK-28.4 (encryption.keySource: "Microsoft.Keyvault", encryption.keyvaultproperties with keyName, keyVaultUri, keyVersion)
- UAMI identity from TASK-28.3 assigned via identity block (type: "UserAssigned")
- encryption.identity.userAssignedIdentity set to the UAMI resource ID
- publicNetworkAccess: "Disabled"
- minimumTlsVersion: "TLS1_2"
- allowBlobPublicAccess: false

**Blob Container** (azapi_resource, Microsoft.Storage/storageAccounts/blobServices/containers@2023-01-01):
- Container name: tfstate (for Terraform remote state)

**Private Endpoints** (using PE module from TASK-28.7):
1. Storage Account PE: group_id "blob", subnet snet-private-endpoints, DNS zone privatelink.blob.core.windows.net from TASK-28.11
2. Key Vault PE: group_id "vault", subnet snet-private-endpoints, DNS zone privatelink.vaultcore.azure.net from TASK-28.11

Both PEs auto-register DNS A records in their respective Private DNS zones via the PE module's DNS zone group resource.
<!-- SECTION:DESCRIPTION:END -->

## Acceptance Criteria
<!-- AC:BEGIN -->
- [ ] #1 Storage account provisioned via azapi_resource with type Microsoft.Storage/storageAccounts@2023-01-01
- [ ] #2 Storage account named klcstgkafkalabscus (no hyphens, storage account naming rules)
- [ ] #3 Storage account kind is StorageV2 with Standard_LRS replication
- [ ] #4 CMEK encryption configured using Key Vault key from TASK-28.4 via encryption.keySource Microsoft.Keyvault and encryption.keyvaultproperties
- [ ] #5 UAMI from TASK-28.3 assigned to storage account via identity block (type UserAssigned)
- [ ] #6 publicNetworkAccess set to Disabled on the storage account
- [ ] #7 minimumTlsVersion set to TLS1_2
- [ ] #8 allowBlobPublicAccess set to false
- [ ] #9 Blob container named tfstate created via azapi_resource with type Microsoft.Storage/storageAccounts/blobServices/containers@2023-01-01
- [ ] #10 Private endpoint for storage account (group_id blob) created in snet-private-endpoints using PE module from TASK-28.7
- [ ] #11 Private DNS A record auto-registered in privatelink.blob.core.windows.net zone via PE DNS zone group
- [ ] #12 Private endpoint for Key Vault (group_id vault) created in snet-private-endpoints using PE module from TASK-28.7
- [ ] #13 Private DNS A record auto-registered in privatelink.vaultcore.azure.net zone via PE DNS zone group
- [ ] #14 terraform validate passes in terraform/environments/dev/
<!-- AC:END -->

## Implementation Notes

<!-- SECTION:NOTES:BEGIN -->
## [TL] 2026-03-30T19:50:00Z
- Assigned to coder-1 (Wave 4, final task)
- All 5 dependencies Done
- Modifies main.tf (storage account, blob container, 2 private endpoints)
<!-- SECTION:NOTES:END -->
