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
