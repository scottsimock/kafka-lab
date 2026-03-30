---
id: TASK-28.3
title: SP1.003 — User Assigned Managed Identity Module
status: Done
assignee:
  - tester-1
created_date: '2026-03-30 16:38'
updated_date: '2026-03-30 19:26'
labels:
  - story
milestone: m-1
dependencies:
  - TASK-28.1
references:
  - terraform/modules/managed-identity/
documentation:
  - doc-14
parent_task_id: TASK-28
priority: high
ordinal: 1003
---

## Description

<!-- SECTION:DESCRIPTION:BEGIN -->
Create a reusable Terraform module at terraform/modules/managed-identity/ that provisions a User Assigned Managed Identity (UAMI) using azapi_resource with type Microsoft.ManagedIdentity/userAssignedIdentities@2023-01-31. The module accepts name, location, resource_group_id, and tags as inputs. Outputs: uami_id (full resource ID), uami_principal_id (the service principal object ID), uami_client_id (the application/client ID). Use response_export_values to extract principalId and clientId from the API response.

Instantiate the first UAMI in the root module (terraform/environments/dev/main.tf) for Key Vault and storage operations: klc-id-kafkalab-scus. This identity will be granted crypto and storage permissions by later tasks.

Each module must include its own versions.tf with required_providers for azapi.
<!-- SECTION:DESCRIPTION:END -->

## Acceptance Criteria
<!-- AC:BEGIN -->
- [x] #1 Module directory exists at terraform/modules/managed-identity/ with main.tf, variables.tf, outputs.tf, versions.tf
- [x] #2 versions.tf declares azapi provider (source azure/azapi) >= 2.0
- [x] #3 main.tf uses azapi_resource with type Microsoft.ManagedIdentity/userAssignedIdentities@2023-01-31
- [x] #4 variables.tf defines name (string), location (string), resource_group_id (string), tags (map of string, default {})
- [x] #5 outputs.tf exports uami_id (full resource ID), uami_principal_id, and uami_client_id
- [x] #6 response_export_values extracts properties.principalId and properties.clientId from API response
- [x] #7 Root module (terraform/environments/dev/main.tf) instantiates the module as klc-id-kafkalab-scus
- [x] #8 terraform validate passes in terraform/environments/dev/
<!-- AC:END -->

## Implementation Notes

<!-- SECTION:NOTES:BEGIN -->
## [TL] 2026-03-30T19:21:00Z
- Assigned to coder-1 (Wave 2, priority 1)
- TASK-28.1 completed, project structure ready
- Critical path: unblocks TASK-28.4 (Key Vault)

## [Coder] 2026-03-30T19:30:00Z
- Created terraform/modules/managed-identity/ with main.tf, variables.tf, outputs.tf, versions.tf
- azapi_resource type: Microsoft.ManagedIdentity/userAssignedIdentities@2023-01-31
- response_export_values extracts properties.principalId and properties.clientId
- Updated terraform/environments/dev/main.tf with module call uami_kafkalab -> klc-id-kafkalab-scus
- terraform fmt -recursive and terraform validate both pass
- Committed: feat(SP1.003): user assigned managed identity module (f94200d)

## [Tester] 2026-03-30T19:35:00Z

### Review: SP1.003 — User Assigned Managed Identity Module

**Files reviewed:**
- terraform/modules/managed-identity/main.tf
- terraform/modules/managed-identity/variables.tf
- terraform/modules/managed-identity/outputs.tf
- terraform/modules/managed-identity/versions.tf
- terraform/environments/dev/main.tf (module instantiation)

**Validation results:**
- `terraform fmt -check -recursive`: PASS (exit 0)
- `terraform validate`: PASS — "The configuration is valid."

**Score Breakdown:**

| Category | Score | Notes |
|---|---|---|
| Acceptance Criteria | 30/30 | All 8 AC items confirmed met |
| Tests | 25/25 | Both fmt and validate pass |
| Code Quality | 20/20 | `//` comments used, snake_case throughout, clean structure |
| Documentation | 15/15 | All vars and outputs have descriptions, no trailing periods |
| Dependencies | 10/10 | No broken imports, validate clean, TASK-28.1 dependency satisfied |

**Total: 100/100 (100%) — PASS**

**Findings:**
- azapi_resource type is correct: `Microsoft.ManagedIdentity/userAssignedIdentities@2023-01-31`
- `response_export_values` correctly extracts both `properties.principalId` and `properties.clientId`
- Outputs correctly reference `azapi_resource.main.output.properties.principalId` and `.clientId`
- Root module instantiates as `uami_kafkalab` with name `klc-id-kafkalab-scus` — correct
- versions.tf properly scoped to azapi only (>= 2.0)
<!-- SECTION:NOTES:END -->
