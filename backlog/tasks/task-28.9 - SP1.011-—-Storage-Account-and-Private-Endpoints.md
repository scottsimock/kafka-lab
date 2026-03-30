---
id: TASK-28.9
title: SP1.011 — Storage Account and Private Endpoints
status: Done
assignee:
  - tester-1
created_date: '2026-03-30 16:40'
updated_date: '2026-03-30 20:01'
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

## [TL] 2026-03-30T20:02:00Z
- Coder agent completed file edits but did not commit (agent stalled)
- TL verified changes: storage account, blob container, 2 PE modules all correct
- terraform init + validate: PASS
- Committed on behalf of coder: feat(SP1.011): storage account and private endpoints
- Sending to tester

## [Tester] 2026-03-30T20:10:00Z

### Verification Checklist
- [x] Storage account type = Microsoft.Storage/storageAccounts@2023-01-01
- [x] Storage account name = klcstgkafkalabscus
- [x] kind = StorageV2, sku.name = Standard_LRS
- [x] CMEK: keySource = "Microsoft.Keyvault", keyvaultproperties present
- [x] UAMI identity block with type = "UserAssigned"
- [x] publicNetworkAccess = "Disabled"
- [x] minimumTlsVersion = "TLS1_2"
- [x] allowBlobPublicAccess = false
- [x] Blob container type = Microsoft.Storage/storageAccounts/blobServices/containers@2023-01-01
- [x] Container name = tfstate
- [x] PE module pe_storage_blob with group_ids = ["blob"]
- [x] PE module pe_key_vault with group_ids = ["vault"]
- [x] Both PEs use snet-private-endpoints subnet
- [x] Both PEs wire dns_zone_ids from module.private_dns_zones

### Score Breakdown
| Category | Weight | Score | Notes |
|---|---|---|---|
| Acceptance Criteria | 30 | 28 | 14/14 AC met. Minor: keyvaultproperties uses lowercase field names (keyname, keyvaulturi) instead of camelCase (keyName, keyVaultUri) per Azure REST API spec; Azure is case-insensitive in practice but deviates from description. keyVersion omitted (valid — Azure auto-uses latest key version). |
| Tests | 25 | 25 | terraform fmt -check: PASS. terraform validate: PASS. |
| Code Quality | 20 | 20 | Section headers (// ===), snake_case resource names, clean structure throughout. |
| Documentation | 15 | 15 | All 3 new outputs (storage_account_id, pe_storage_blob_id, pe_key_vault_id) have descriptions. |
| Dependencies | 10 | 10 | All 5 task dependencies wired correctly. Module paths valid. No broken references. |
| **Total** | **100** | **98** | **PASS (threshold: 90%)** |
<!-- SECTION:NOTES:END -->
