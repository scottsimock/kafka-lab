---
id: TASK-27.10
title: SP0.010 — GitHub Actions CI/CD for Azure
status: Done
assignee:
  - tester-15
created_date: '2026-03-30 15:22'
updated_date: '2026-03-30 16:13'
labels:
  - research
milestone: m-0
dependencies: []
references:
  - 'https://learn.microsoft.com/en-us/azure/developer/github/github-actions'
parent_task_id: TASK-27
priority: medium
ordinal: 10000
---

## Description

<!-- SECTION:DESCRIPTION:BEGIN -->
**Objective:** Research GitHub Actions workflow patterns for Azure infrastructure deployments. The project requires one-click deployment capability: Terraform → Ansible → App, with OIDC authentication, environment protection rules, and drift detection.\n\n**Sources:**\n- https://learn.microsoft.com/en-us/azure/developer/github/github-actions\n- https://docs.github.com/en/actions/deployment/security-hardening-your-deployments/configuring-openid-connect-in-azure\n- https://docs.github.com/en/actions/using-workflows/workflow-syntax-for-github-actions\n- GitHub Actions best practices for infrastructure deployment\n\n**Output:** A backlog document created via `backlog-document_create` containing:\n- Executive summary of CI/CD strategy\n- OIDC authentication setup (Azure AD app registration, federated credentials, GitHub secrets)\n- Workflow structure (reusable workflows, job dependencies, environment matrices)\n- Terraform jobs (init, plan, apply, drift detection, state management)\n- Ansible jobs (dynamic inventory, playbook execution, vault integration)\n- Application deployment jobs (Next.js build, Function App deployment)\n- workflow_dispatch for one-click deployment (inputs, environment selection)\n- Secrets management (GitHub secrets, OIDC tokens, Key Vault integration)\n- Environment protection rules (required reviewers, wait timers, branch restrictions)\n- Example workflow YAML\n- References with URLs\n\n**Scope:**\n- Include: OIDC setup, workflow structure, Terraform jobs, Ansible jobs, workflow_dispatch, secrets, environments\n- Exclude: Specific Terraform/Ansible content (SP0.008/SP0.009), application code details (SP0.011)
<!-- SECTION:DESCRIPTION:END -->

## Acceptance Criteria
<!-- AC:BEGIN -->
- [x] #1 Document covers OIDC authentication setup between GitHub Actions and Azure
- [x] #2 Document covers workflow structure (Terraform plan/apply jobs, Ansible jobs)
- [x] #3 Document covers workflow_dispatch for one-click deployment
- [x] #4 Document covers secrets management (OIDC, environment variables, Key Vault integration)
- [x] #5 Document covers environment protection rules and approval gates
<!-- AC:END -->

## Implementation Notes

<!-- SECTION:NOTES:BEGIN -->
## [Coder] 2026-03-30T12:09:00 EDT
- Researched GitHub Actions OIDC with Azure using primary sources: GitHub Docs, Microsoft Learn
- Researched reusable workflows, Terraform plan/apply patterns, Ansible dynamic inventory with UAMI, Key Vault integration, and environment protection rules
- Created backlog document `doc-17 — SP0.010 — GitHub Actions CI/CD for Azure`
- Document covers all 5 AC items: OIDC setup, workflow structure, workflow_dispatch, secrets management, environment protection rules
- Key findings:
  - UAMI (not App Registration) is the preferred federated identity target per project instructions
  - `azure/get-keyvault-secrets` is archived — Key Vault access must use `azure/CLI@v2` with `az keyvault secret show`
  - Ansible dynamic inventory with UAMI requires a self-hosted runner on an Azure VM (GitHub-hosted runners have no MSI context)
  - `ARM_USE_OIDC=true` + `ARM_USE_AZUREAD=true` enables OIDC for both Terraform provider and Azure Blob Storage backend
  - Drift detection uses `terraform plan -detailed-exitcode` (exit code 2 = drift) on a nightly cron schedule
  - `secrets: inherit` on reusable workflow calls propagates environment secrets without explicit enumeration
- Sources: 15 URLs cited in References section

## [Tester] 2026-03-30T12:30:00 EDT

### Research Rubric Score: 96.95% — PASS (threshold: 95%)

| Category | Weight | Score | Weighted |
|---|---|---|---|
| Accuracy | 30% | 96% | 0.288 |
| Completeness | 25% | 98% | 0.245 |
| Sources | 20% | 97% | 0.194 |
| Documentation Quality | 15% | 97% | 0.1455 |
| Actionability | 10% | 97% | 0.097 |
| **Total** | | | **96.95%** |

### Accuracy (96%)
- OIDC setup correctly targets UAMI per project mandate — App Registration explicitly listed as secondary option only
- `ARM_USE_OIDC: "true"` + `ARM_USE_AZUREAD: "true"` flags correct for both AzureRM provider and Azure Blob Storage backend
- `use_oidc = true` in backend HCL config is correct
- `azure/login@v2` with client-id/tenant-id/subscription-id (no secret) is correct OIDC pattern
- `id-token: write` permission declaration correct on all OIDC-using jobs
- `azure/get-keyvault-secrets` correctly flagged as archived; `azure/CLI@v2` substitution is accurate
- `PIPESTATUS[0]` usage in drift detection bash is correct for capturing exit code through `tee` pipe
- Federated credential subjects scoped per environment (no wildcard) — correct security posture
- Minor: `AZURE_USE_MSI: "true"` for Ansible self-hosted runner context is broadly correct

### Completeness (98%)
- All 5 AC items fully addressed with dedicated sections
- AC1: OIDC setup — 6-step walkthrough (create UAMI, RBAC, federated creds, secrets, permissions, login step)
- AC2: Workflow structure — Terraform plan/apply/drift, Ansible dynamic inventory + vault, App deployment
- AC3: workflow_dispatch — 4 structured inputs with choice/boolean types, job condition guards
- AC4: Secrets management — table of categories, Key Vault retrieval pattern, masking rules, OIDC token lifecycle
- AC5: Environment protection rules — 3-environment matrix (dev/staging/prod) with reviewers, wait timers, branch restrictions
- Bonus: drift detection, multi-region matrix strategy, PR comment integration, branch protection rules

### Sources (97%)
- 15 URLs cited with descriptive titles
- Primary sources: GitHub Docs, Microsoft Learn, HashiCorp Developer, Ansible Docs
- Reference implementations: Azure-Samples/terraform-github-actions
- All GitHub action repos linked directly

### Documentation Quality (97%)
- Clear executive summary covering the full strategy in one reading
- ASCII job dependency diagram aids understanding
- All code blocks have language identifiers (yaml, bash, hcl)
- Tables used effectively for auth options, secrets categories, environment matrix
- Security callouts (masking, no wildcard subjects, $GITHUB_ENV vs $GITHUB_OUTPUT) well-placed

### Actionability (97%)
- Project-specific resource names used throughout (klc-rg-kafkalab-scus, klc-kv-kafkalab-scus, klc-app/func naming)
- UAMI naming conventions match project style
- Complete file structure defined for .github/workflows/
- Region references match Azure environment instructions (southcentralus, mexicocentral)
- RBAC role assignments are specific and implementable
<!-- SECTION:NOTES:END -->
