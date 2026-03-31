# Project Context

- **Project:** kafka-lab — Confluent Kafka resiliency lab on Azure
- **Stack:** Terraform (AzAPI), Ansible, Next.js 15, GitHub Actions, Azure VMs
- **User:** simock
- **Created:** 2026-03-31

## Core Context

Infrastructure developer for kafka-lab. SP0–SP4 complete. My domain covers Terraform modules, Ansible roles, Azure networking, and CI/CD workflows.

### Existing Infrastructure

- `terraform/modules/` — key-vault, managed-identity, network-security-group, private-dns-zone, private-endpoint, virtual-machine, virtual-network
- `terraform/environments/` — environment-specific configurations
- `ansible/roles/` — common, confluent-common, disk-setup, java, kafka-broker, kafka-client-creds, kafka-connect, schema-registry, tls-certs, zookeeper
- Azure regions: southcentralus (primary, zones 1-2), mexicocentral (secondary, zone 1), canadaeast (DR, zone 1)
- Resource group: klc-rg-kafkalab-scus

### Upcoming Work

- SP6: CI/CD pipeline — Terraform/Ansible/web app deployment workflows, one-click deploy, drift detection
- SP7: Multi-region — secondary/DR VNets, full mesh peering, cross-region DNS, multi-region VMs, cluster linking
- SP8: Resiliency — Chaos Studio, Front Door, monitoring, production config

## Recent Updates

📌 Team initialized on 2026-03-31

## Learnings

Initial setup complete. Replacing Ruby sprint orchestrator with Squad workflow.

### Terraform skill consolidation (2025-07-23)

Merged `.github/instructions/coding-standards/terraform.instructions.md` (general Terraform conventions: project structure, file organization, naming, variables/outputs, comment style, modules, expression functions, data sources, resource naming, provider config, state management, lifecycle, documentation) into `.github/skills/terraform-azapi/SKILL.md`. The SKILL.md now serves as the single authoritative reference for all Terraform work in this project. Overlapping content (for_each guidance, provider version blocks) was deduplicated, keeping the more complete version in each case. The instructions file was deleted.

### Ansible skill consolidation (2025-07-23)

Merged `.github/instructions/coding-standards/ansible.instructions.md` (general instructions, secret management, style conventions, linting) into `.github/skills/ansible/SKILL.md`. The SKILL.md now serves as the single authoritative reference for all Ansible work in this project. Style Rules was expanded from 7 bullets into 12 subsections covering naming, quoting, map syntax, host/task ordering, include statements, comments, and task grouping. New sections added: Secret Management (vault_ prefix pattern, group_vars structure, third-party secrets) and Linting (ansible-lint, yamllint, syntax-check, check --diff). Overlapping content (FQCN, become, state, dynamic inventory, shell/command avoidance) was deduplicated, keeping the more detailed version. The instructions file was deleted.

### Function App module created (SP5.009, 2026-03-31)

Created `terraform/modules/function-app/` for Azure Function App infrastructure. Module provisions Premium EP1 App Service Plan (required for VNet integration), Standard_LRS storage account with TLS 1.2 minimum and private network access, and Function App configured for Node|20 runtime with Custom worker. Function App integrates with VNet via `web_app_subnet_id` variable and references Kafka secrets from Key Vault using `@Microsoft.KeyVault(VaultName=...;SecretName=...)` pattern in app settings. Module includes RBAC assignment granting the UAMI Key Vault Secrets User role (4633458b-17de-408a-b874-0445c86b69e6) for secret access. All resources use AzAPI provider with 2023-12-01 API versions following established module pattern (main.tf, variables.tf, outputs.tf, versions.tf). Storage account connection string uses property reference syntax for blob endpoint. Module ready for environment wiring in SP5.010.

### SP5 review fixes (2026-03-31)

Fixed three critical issues from Ripley's SP5 review:
1. Storage authentication: Replaced broken `AzureWebJobsStorage` connection string (was incorrectly using blob endpoint URL) with `AzureWebJobsStorage__accountName` for managed identity authentication. Added Storage Blob Data Owner (b7e6dc6d-f1e8-4753-8033-0f276bb0955b) and Storage Queue Data Contributor (974c5e8b-45b9-4653-ba55-5f855dd0fb88) RBAC roles for UAMI on storage account. This approach is more secure and aligns with Azure Functions best practices for VNet-integrated apps.
2. Schema Registry URL: Added `schema_registry_url` variable and `SCHEMA_REGISTRY_URL` app setting to Function App. The webapp code references this environment variable but it was missing from Terraform configuration.
3. Consumer group state badge: Fixed case mismatch in `webapp/lib/api/consumer-groups.ts` by normalizing `formatConsumerGroupState` output to title case (Stable, Rebalancing, Empty, Dead) to match dashboard page comparisons. This was Dallas's code (reviewer lockout scenario).

Key learning: Azure Functions storage connection for VNet-integrated apps should use managed identity pattern (`AzureWebJobsStorage__accountName` + RBAC roles) rather than connection strings with account keys. The blob endpoint URL is not a valid connection string format.

### SP5 Complete (2026-03-31)

SP5 — Web Application sprint is COMPLETE. Delivered SP5.009 (Function App Terraform module) and applied 3 critical fixes from Ripley's review (storage auth managed identity, Schema Registry URL env var, consumer group state badge case). All 10 tasks passed quality review. Average score ~99%. Branch: sprint/SP5-web-application (14 commits).

### SP7 backlog injection (2026-03-31)

Injected new SP7 — Dev Environment Deployment & Integration Testing between SP6 (CI/CD) and the former SP7 (Multi-Region). Renamed old SP7 → SP8, old SP8 → SP9. Created 10 stories covering: Azure deployment, Playwright framework setup, Playwright MCP integration, smoke tests, integration tests (dashboard, operations, schema registry), E2E validation, CI/CD for tests, and teardown/cost management. Sprint parent: TASK-36. Milestone: SP7 (m-9). Decision documented in `.squad/decisions/inbox/zorg-sp7-backlog-refactor.md`.

Key pattern: when renaming sprint numbers, process in reverse order (highest number first) to avoid milestone name conflicts. Backlog MCP `milestone_rename` with `updateTasks: true` handles milestone references on tasks automatically, but task titles must be updated individually via `task_edit`. Dependencies use internal task IDs (TASK-N) which are stable across renames — only titles and milestone display names shift.


## SP7 Sprint Completion — Dev Environment & Integration Testing (2026-03-31T18:13-04:00)

**Sprint Status:** COMPLETE (10/10 tasks) | 100% Success Rate

**Team Composition:**
- Drexl (Infra Dev): SP7.001, SP7.009, SP7.010
- Smiley (Frontend Dev): SP7.002, SP7.003
- Sid (Tester): SP7.004, SP7.005, SP7.006, SP7.007, SP7.008

**Wave Execution:**
- **Wave 1 (14:35 ET):** Infrastructure + framework foundation (Drexl, Smiley, Sid)
- **Wave 2 (15:20 ET):** Playwright MCP + dashboard tests (Smiley, Sid)
- **Wave 3 (16:10 ET):** Kafka operations + schema registry tests (Sid)
- **Wave 4 (17:00 ET):** CI/CD pipeline + cost management + E2E validation (Drexl, Sid)

**Key Metrics:**
- Tasks Completed: 10/10 (100%)
- Tests Written: 110 Playwright tests
- Test Files: 18 spec files
- CI/CD Workflows: 3 (.yml files)
- Infrastructure Modules: 1 (dev-environment)
- Documentation: 5 guides
- Average Task Quality: ~99%

**Orchestration Artifacts:**
- `.squad/orchestration-log/2026-03-31T14-35-wave1.md`
- `.squad/orchestration-log/2026-03-31T15-20-wave2.md`
- `.squad/orchestration-log/2026-03-31T16-10-wave3.md`
- `.squad/orchestration-log/2026-03-31T17-00-wave4.md`
- `.squad/log/2026-03-31T18-13-sp7-sprint-execution.md`

**Key Decisions Made:**
1. Fast-fail gate: Smoke tests run first (~2 min) before full integration suite (~8 min)
2. Cost optimization: Nightly teardown reduces daily cost ~99% ($45-55/day → $0.10/day)
3. Dual validation: Ansible playbook + bash script for maximum compatibility
4. Premium EP1 plan: VNet integration required for production-like dev environment

**Architecture Evolution:**
- SP0–SP4: Foundation (infrastructure, Kafka platform, ecosystem)
- SP5: Web application (Next.js 15, Azure Functions)
- SP6: CI/CD (Terraform/Ansible deployment workflows)
- SP7: Dev environment & testing (Playwright, E2E validation, cost management)
- SP8: Multi-region (cross-region peering, cluster linking)
- SP9: Resiliency (chaos experiments, failover, production hardening)

**Next Sprint (SP8):** Multi-region expansion — secondary/DR VNets, full mesh peering, cross-region DNS, multi-region cluster linking
