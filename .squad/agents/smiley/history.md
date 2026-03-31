# Project Context

- **Project:** kafka-lab — Confluent Kafka resiliency lab on Azure
- **Stack:** Terraform (AzAPI), Ansible, Next.js 15, GitHub Actions, Azure VMs
- **User:** simock
- **Created:** 2026-03-31

## Core Context

Lead agent for kafka-lab. SP0–SP4 complete (foundation infra, compute, Kafka platform, ecosystem services). Remaining: SP5 (Web App), SP6 (CI/CD), SP7 (Multi-Region), SP8 (Resiliency).

### Codebase Structure

- `terraform/modules/` — key-vault, managed-identity, network-security-group, private-dns-zone, private-endpoint, virtual-machine, virtual-network
- `terraform/environments/` — environment-specific configs
- `ansible/roles/` — common, confluent-common, disk-setup, java, kafka-broker, kafka-client-creds, kafka-connect, schema-registry, tls-certs, zookeeper
- `ansible/playbooks/` — deployment and verification playbooks
- `backlog/` — sprint tasks and milestones (SP0–SP8)
- Azure regions: southcentralus (primary), mexicocentral (secondary), canadaeast (DR)

### Previous Sprint History

- SP1: Foundation infrastructure — VNet, KV, UAMI, DNS, NSG, Storage, Private Endpoints (PR #2)
- SP2: Compute — VM module, ZK/Broker/SR/Connect VMs, Ansible roles for OS/disk/Java/Confluent (PR #3)
- SP3: Kafka platform — ZK role, Broker role, TLS, SASL/SCRAM, tiered storage, self-balancing, ACLs (PR #4)
- SP4: Ecosystem — Schema Registry role, Kafka Connect role, Blob sink connector, topic creation, schema registration (PR #5)

## Recent Updates

📌 Team initialized on 2026-03-31

## Learnings

Initial setup complete. Replacing Ruby sprint orchestrator with Squad workflow.

### Sprint Report Generation (2026-04-01)

Established sprint report format and location:

- **Format:** Individual sprint reports (`.squad/reports/SP{N}-report.md`) include summary stats, deliverables list, task table, key decisions, team contributions, and notes
- **Consolidated summary:** `.squad/reports/sprint-summary.md` provides progress overview table, cumulative stats, architecture evolution narrative, and next steps
- **Location:** All reports live in `.squad/reports/` directory
- **Generated from:** Backlog task data (parent tasks TASK-27 through TASK-32 for SP0-SP5)
- **Quality tracking:** Individual sprint average scores and overall cumulative average (99.7% across 60 tasks)
- **Architecture narrative:** Sprint reports document how the system evolved from foundation → compute → platform → ecosystem → webapp

### Sprint Workflow Instructions Rewrite (2026-03-31)

Rewrote `.github/instructions/sprint-workflow.instructions.md` to strip out Ruby/PO/SM/TL/Coder/Tester orchestration content. The file now focuses exclusively on conventions that all agents need:

- **Kept:** Naming conventions (backlog IDs, task titles, labels, parent-child structure), git branches (`sprint/SP{N}-{description}`), commit message format (`feat(SP{N}.{NNN}): {description}`), milestones, quality rubrics (coding 90%, research 95%), task status machine, work logging format, documents pattern, technical debt/carryover rules
- **Removed:** Architecture diagram, sprint lifecycle phases, agent execution modes table, Sprint 0 special structure, SP0 state detection, agent communication with role tags, Ruby-owned PR lifecycle, execution rules table (concurrent limits, retry cycles)
- **Updated:** Title and description to reflect conventions-only scope, task status machine to be orchestrator-agnostic, technical debt section removed PO references, task assignment tracking updated to Squad agent names

The file is now 138 lines (down from 333). Orchestration rules now live exclusively in `.github/agents/squad.agent.md` and `.squad/` files where Squad agents manage them.

### Azure Environment Consolidation (2026-03-31)

Consolidated Azure environment compliance documentation into REQUIREMENTS.md:

- **Merged:** `.github/instructions/coding-standards/azure-environment.instructions.md` content into new `## Azure Environment` section in REQUIREMENTS.md (placed between Project Overview and References)
- **Content preserved:** All compliance requirements (CMEK per resource, UAMI per workflow, TLS 1.2+ minimum, private VNets, private endpoints, private DNS zones, public ingress restrictions for web app only, Let's Encrypt automation)
- **Code examples retained:** All HCL compliance tag examples kept intact for agent reference when writing Terraform
- **Reference updated:** Line 7 of REQUIREMENTS.md changed from "azure-environment instructions file" to "Azure Environment section below"
- **Cleanup:** Deleted redundant instructions file; removed empty `coding-standards/` directory
- **Rationale:** REQUIREMENTS.md is the single source of truth for project requirements. Inlining compliance context eliminates instruction file fragmentation and ensures compliance guidance is always visible alongside project scope and architecture choices

### SP5 Web Application Review (2026-04-01)

Reviewed full SP5 sprint branch (`sprint/SP5-web-application` vs `main`) — 114 files, ~15K lines covering Terraform Function App module and Next.js 15 webapp.

**Verdict:** APPROVE WITH CONDITIONS (3 critical items to fix before merge)

**Critical findings:**
1. **Storage connection string broken** — `terraform/modules/function-app/main.tf` line 119 constructs `AzureWebJobsStorage` using `primaryEndpoints.blob` (a URL) where it needs an account key. Function App will fail at runtime.
2. **Missing `SCHEMA_REGISTRY_URL` in Function App appSettings** — The webapp reads this env var but Terraform never sets it. Schema browser will only work if internal DNS resolves the hardcoded hostname.
3. **`formatConsumerGroupState` case mismatch** — Function uppercases state strings but the page compares against mixed-case `'Stable'`. State badges always show yellow.

**Warnings:**
- Schema browser and message views use Tailwind CSS classes but Tailwind is not installed (no visual styling)
- Ephemeral consumer groups created per consume request accumulate in broker metadata
- SSE stream abort handler needs additional try/catch around `controller.close()`
- `any` type used for consumer group member assignments

**Architecture assessment:** Sound. Webapp follows decisions doc precisely — Server Components default, client-only for interactivity, direct Schema Registry fetch, webpack externals for native Kafka module, standalone output for Azure Functions custom handler. Terraform module structure (4-file, AzAPI, `//` comments, `snake_case`) follows all conventions.

**Build result:** `npm run build` passes clean. All 20 routes compile. Terraform `fmt` clean, no `#` comments.

### Sprint Reports Generated (2026-04-01)

Generated comprehensive sprint reports for SP0 through SP5:

- **Scope:** 6 individual reports (SP0-report.md through SP5-report.md) + consolidated summary (sprint-summary.md)
- **Data:** Backlog task completion records, quality scores, team contributions, key decisions, architectural evolution
- **Location:** `.squad/reports/`
- **Team:** Dallas, Parker, Lambert, Ripley contributed work across all sprints
- **Coverage:** 50 total sprint tasks across 5 development sprints + SP0 research/planning
- **Quality:** Cumulative quality average 96%+ across all sprints
- **Architecture:** Progressive delivery from foundation infrastructure → compute → Kafka platform → ecosystem → web app

Reports serve as historical record for retrospectives, progress tracking, and knowledge transfer. Available for cross-team reference on project evolution and decision rationale.
