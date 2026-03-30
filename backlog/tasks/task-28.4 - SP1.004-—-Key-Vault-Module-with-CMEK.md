---
id: TASK-28.4
title: SP1.004 — Key Vault Module with CMEK
status: Done
assignee:
  - tester-1
created_date: '2026-03-30 16:38'
updated_date: '2026-03-30 19:36'
labels:
  - story
milestone: m-1
dependencies:
  - TASK-28.1
  - TASK-28.3
references:
  - terraform/modules/key-vault/
  - terraform/environments/dev/main.tf
documentation:
  - doc-14
parent_task_id: TASK-28
priority: high
ordinal: 1004
---

## Description

<!-- SECTION:DESCRIPTION:BEGIN -->
Create a reusable Terraform module at terraform/modules/key-vault/ that provisions Azure Key Vault using azapi_resource with type Microsoft.KeyVault/vaults@2023-07-01. The Key Vault must have: purge protection enabled (enablePurgeProtection: true), soft delete with 90-day retention (softDeleteRetentionInDays: 90), public network access disabled (publicNetworkAccess: "Disabled"), TLS 1.2 minimum, SKU standard.

Use RBAC authorization model (enableRbacAuthorization: true) instead of vault access policies. Accept uami_principal_id as input and assign the "Key Vault Crypto Officer" role via azapi_resource with type Microsoft.Authorization/roleAssignments@2022-04-01 scoped to the vault.

Create a CMEK encryption key within the vault using azapi_resource with type Microsoft.KeyVault/vaults/keys@2023-07-01. The key should be RSA 2048-bit with wrapKey and unwrapKey operations.

Outputs: key_vault_id, key_vault_uri, key_vault_name, cmk_key_id (the full resource ID of the encryption key), cmk_key_versionless_id (key ID without version for CMEK references).

Instantiate in root module as klc-kv-kafkalab-scus. The UAMI from TASK-28.3 must be passed as input to receive crypto permissions.
<!-- SECTION:DESCRIPTION:END -->

## Acceptance Criteria
<!-- AC:BEGIN -->
- [ ] #1 Module directory exists at terraform/modules/key-vault/ with main.tf, variables.tf, outputs.tf, versions.tf
- [ ] #2 main.tf uses azapi_resource with type Microsoft.KeyVault/vaults@2023-07-01
- [ ] #3 Key Vault has enablePurgeProtection set to true
- [ ] #4 Key Vault has softDeleteRetentionInDays set to 90
- [ ] #5 Key Vault has publicNetworkAccess set to Disabled
- [ ] #6 Key Vault uses enableRbacAuthorization set to true (RBAC model, not access policies)
- [ ] #7 Key Vault SKU is set to standard
- [ ] #8 CMEK key created via azapi_resource with type Microsoft.KeyVault/vaults/keys@2023-07-01 as RSA 2048-bit
- [ ] #9 CMEK key operations include wrapKey and unwrapKey
- [ ] #10 UAMI role assignment for Key Vault Crypto Officer created via Microsoft.Authorization/roleAssignments@2022-04-01
- [ ] #11 Outputs include key_vault_id, key_vault_uri, key_vault_name, cmk_key_id, and cmk_key_versionless_id
- [ ] #12 Root module instantiates Key Vault as klc-kv-kafkalab-scus with UAMI from TASK-28.3
- [ ] #13 terraform validate passes in terraform/environments/dev/
<!-- AC:END -->

## Implementation Notes

<!-- SECTION:NOTES:BEGIN -->
## [TL] 2026-03-30T19:28:00Z
- Assigned to coder-1 (Wave 3 start)
- Dependencies 28.1 and 28.3 both Done
- Modifies main.tf - serialized with other main.tf tasks

## [Coder] 2026-03-30T19:45:00Z
- Created terraform/modules/key-vault/ with main.tf, variables.tf, outputs.tf, versions.tf
- Key Vault: azapi_resource Microsoft.KeyVault/vaults@2023-07-01, standard SKU, RBAC auth, purge protection, 90-day soft-delete, public access disabled
- CMEK key: azapi_resource Microsoft.KeyVault/vaults/keys@2023-07-01, RSA 2048-bit, wrapKey/unwrapKey ops
- Role assignment: Microsoft.Authorization/roleAssignments@2022-04-01, Key Vault Crypto Officer (14b46e9e), scoped to vault
- random_uuid used for deterministic role assignment name
- Appended key_vault and data.azapi_client_config to terraform/environments/dev/main.tf
- Appended key_vault_id and cmk_key_id outputs to terraform/environments/dev/outputs.tf
- terraform fmt and terraform validate both pass
- Committed: feat(SP1.004): key vault module with cmek

## [Tester] 2026-03-30T19:50:00Z

### Review: SP1.004 — Key Vault Module with CMEK

**Score: 100/100 — PASS ✅**

#### Acceptance Criteria — 30/30
- [x] AC1: Module directory exists with all four required files (main.tf, variables.tf, outputs.tf, versions.tf)
- [x] AC2: azapi_resource uses type `Microsoft.KeyVault/vaults@2023-07-01`
- [x] AC3: `enablePurgeProtection = true`
- [x] AC4: `softDeleteRetentionInDays = 90`
- [x] AC5: `publicNetworkAccess = "Disabled"`
- [x] AC6: `enableRbacAuthorization = true`
- [x] AC7: SKU family A, name `standard`
- [x] AC8: CMEK key via `Microsoft.KeyVault/vaults/keys@2023-07-01`, RSA 2048-bit
- [x] AC9: keyOps = ["wrapKey", "unwrapKey"]
- [x] AC10: Role assignment via `Microsoft.Authorization/roleAssignments@2022-04-01`, Key Vault Crypto Officer (14b46e9e-c2b7-41b4-b07b-48a6ebf60603)
- [x] AC11: Outputs key_vault_id, key_vault_uri, key_vault_name, cmk_key_id, cmk_key_versionless_id — all present with descriptions
- [x] AC12: Root module instantiates as `klc-kv-kafkalab-scus`, wired to `module.uami_kafkalab.uami_principal_id`
- [x] AC13: terraform validate passes

#### Tests — 25/25
- `terraform fmt -check -recursive ../../` → exit 0 ✅
- `terraform validate` → "Success! The configuration is valid." ✅

#### Code Quality — 20/20
- `//` comments only, no `#` comments ✅
- snake_case throughout ✅
- Clean resource ordering: vault → role_assignment (depends_on vault) → cmk_key (depends_on role_assignment) ✅
- random_uuid used correctly for idempotent role assignment naming ✅
- `split()` inline for subscription ID extraction is acceptable ✅

#### Documentation — 15/15
- All 6 variables have descriptions ✅
- All 5 outputs have descriptions ✅

#### Dependencies — 10/10
- UAMI principal ID correctly sourced from TASK-28.3 output ✅
- `data.azapi_client_config.current` properly scoped at env level ✅
- No regressions in existing resources confirmed by validate ✅

#### Key Vault Verification Checklist
- [x] type = `Microsoft.KeyVault/vaults@2023-07-01`
- [x] enablePurgeProtection = true
- [x] softDeleteRetentionInDays = 90
- [x] publicNetworkAccess = "Disabled"
- [x] enableRbacAuthorization = true
- [x] SKU = "standard"
- [x] CMEK: RSA 2048-bit via `Microsoft.KeyVault/vaults/keys@2023-07-01`
- [x] keyOps includes wrapKey and unwrapKey
- [x] Role assignment via `Microsoft.Authorization/roleAssignments@2022-04-01`
- [x] Role definition ID 14b46e9e-c2b7-41b4-b07b-48a6ebf60603 (KV Crypto Officer)
- [x] All 5 required outputs present
- [x] Instantiated as klc-kv-kafkalab-scus
- [x] // comments only
<!-- SECTION:NOTES:END -->
