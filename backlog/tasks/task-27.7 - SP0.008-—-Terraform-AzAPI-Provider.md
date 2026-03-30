---
id: TASK-27.7
title: SP0.008 — Terraform AzAPI Provider
status: Done
assignee:
  - tester-11
created_date: '2026-03-30 15:22'
updated_date: '2026-03-30 16:06'
labels:
  - research
milestone: m-0
dependencies: []
references:
  - >-
    https://learn.microsoft.com/en-us/azure/developer/terraform/overview-azapi-provider
parent_task_id: TASK-27
priority: high
ordinal: 8000
---

## Description

<!-- SECTION:DESCRIPTION:BEGIN -->
**Objective:** Research the Terraform AzAPI provider for Azure resource provisioning. AzAPI is the project's chosen provider (per REQUIREMENTS.md) because it provides direct ARM REST API access with full API version control and support for preview features. Understand how it differs from AzureRM and establish module patterns for the project.\n\n**Sources:**\n- https://learn.microsoft.com/en-us/azure/developer/terraform/overview-azapi-provider\n- https://registry.terraform.io/providers/azure/azapi/latest/docs\n- https://learn.microsoft.com/en-us/azure/developer/terraform/get-started-azapi-resource\n- Terraform AzAPI provider GitHub repository examples\n\n**Output:** A backlog document created via `backlog-document_create` containing:\n- Executive summary of AzAPI vs AzureRM (when to use which)\n- AzAPI resource syntax (`azapi_resource`, `azapi_update_resource`, `azapi_resource_action`)\n- AzAPI data sources (`azapi_resource`, `azapi_resource_list`)\n- API version selection strategy (stable vs preview, version pinning)\n- Module patterns for the project (VNet module, VM module, Key Vault module)\n- State management (Azure Storage backend, locking, import workflows)\n- CI/CD integration (terraform plan in PR, apply on merge, drift detection)\n- Example module structure following project conventions\n- References with URLs\n\n**Scope:**\n- Include: AzAPI resource/data syntax, API versions, module patterns, state management, CI/CD integration\n- Exclude: Specific resource configurations (covered in SP0.006/SP0.007), AzureRM migration
<!-- SECTION:DESCRIPTION:END -->

## Acceptance Criteria
<!-- AC:BEGIN -->
- [x] #1 Document covers AzAPI resource and data source syntax with examples
- [x] #2 Document covers API version selection strategy and version pinning
- [x] #3 Document covers module patterns (inputs, outputs, resource composition)
- [x] #4 Document covers state management (remote backend, locking, import)
- [x] #5 Document covers CI/CD integration patterns (plan, apply, drift detection)
<!-- AC:END -->

## Implementation Notes

<!-- SECTION:NOTES:BEGIN -->
## [Coder] 2026-03-30T12:02:00 EDT
- Researched AzAPI provider using Microsoft Learn, web search, and official documentation
- Sources consulted: overview-azapi-provider, get-started-azapi-resource, get-started-azapi-resource-action, store-state-in-azure-storage, Azure REST API specs, OIDC CI/CD samples
- Created backlog document **doc-14** — `SP0.008 — Terraform AzAPI Provider`
- Document covers all 5 acceptance criteria:
  1. AzAPI resource and data source syntax with full HCL examples (azapi_resource, azapi_update_resource, azapi_resource_action, data.azapi_resource, data.azapi_resource_list)
  2. API version selection strategy: ARM specs repo, stable vs preview, version pinning policy, current stable versions for VNet/VM/KeyVault/Storage
  3. Module patterns: four-file structure (main.tf, variables.tf, outputs.tf, versions.tf), VNet module example, Kafka broker VM module example, module call conventions
  4. State management: Azure Blob Storage backend config with OIDC, locking via blob lease, import block syntax, aztfmigrate reference
  5. CI/CD integration: Plan-on-PR workflow, Apply-on-merge workflow, scheduled drift detection workflow with -detailed-exitcode
- All HCL follows project conventions: kebab-case files, snake_case resources/variables, // comments, no AzureRM

## [Tester] 2026-03-30T12:15:00 EDT

### Review Result: PASS — 96.25%

#### Scoring Breakdown

| Category | Weight | Score | Weighted |
|---|---|---|---|
| Accuracy | 30% | 97% | 29.10% |
| Completeness | 25% | 98% | 24.50% |
| Sources | 20% | 97% | 19.40% |
| Documentation Quality | 15% | 93% | 13.95% |
| Actionability | 10% | 93% | 9.30% |
| **Total** | | | **96.25%** |

Pass threshold: 95% — **PASS**

#### Accuracy (97/100)
- All four AzAPI resource types (`azapi_resource`, `azapi_update_resource`, `azapi_resource_action`, `data.azapi_resource`, `data.azapi_resource_list`, `data.azapi_resource_action`) are correctly documented with accurate syntax.
- `type` field format (`{ResourceType}@{apiVersion}`), `parent_id`, `response_export_values`, `identity` block, and `retry` block all correct.
- `azapi_update_resource` correctly identified as not owning lifecycle and not supporting `response_export_values`.
- API version selection strategy (stable vs preview, explicit pinning, no range specifiers) is accurate.
- State backend uses correct `backend "azurerm"` with `use_oidc = true` and blob lease locking explanation.
- Import block (Terraform 1.5+) and CLI import correctly shown.
- Drift detection `-detailed-exitcode` exit code table (0/1/2) is accurate.
- Minor deduction: YAML CI/CD workflow blocks use `//` for inline comments (e.g., `environment: production  // requires manual approval`) which is invalid YAML — `#` is the YAML comment character. This does not affect research findings but is a code example error.

#### Completeness (98/100)
- All 5 acceptance criteria fully satisfied.
- Executive summary, AzAPI/AzureRM comparison, all resource types, data sources, API version strategy, module patterns (VNet + Kafka broker), state management, CI/CD (plan/apply/drift), example module structure, and references all present.
- No content gaps identified.

#### Sources (97/100)
- 14 references with full URLs. All primary: Microsoft Learn, HashiCorp Developer, Terraform Registry, Azure GitHub repos, Azure Samples.
- Two secondary blog posts for drift detection (dev.to, terrateam.io) — appropriate for the topic, no primary alternatives exist.
- ARM change log and REST API references are specific and directly actionable.

#### Documentation Quality (93/100)
- Executive summary is clear, three-paragraph structure explains AzAPI vs AzureRM and project rationale.
- Document is well-structured with logical H2/H3 hierarchy.
- HCL examples follow all project conventions: snake_case, `//` comments, no AzureRM.
- Tables well-used throughout (field reference, API versions, exit codes, naming conventions).
- Deduction: `//` comments inside YAML workflow blocks are syntactically invalid YAML and would produce unexpected values if used verbatim.

#### Actionability (93/100)
- All four module files shown for both VNet and Kafka broker modules — templates are immediately usable.
- Project-specific naming (klc- prefix, klc-rg-kafkalab-scus) used throughout examples.
- API version reference table gives immediate answers for SP1 implementation.
- CI/CD workflows are complete and runnable.
- Minor deduction: apply workflow uses `terraform apply -input=false -auto-approve` without consuming a saved plan file; safer pattern would save and apply the tfplan artifact from the plan step.
<!-- SECTION:NOTES:END -->
