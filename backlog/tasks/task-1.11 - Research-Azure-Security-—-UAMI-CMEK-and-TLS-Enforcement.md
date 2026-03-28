---
id: TASK-1.11
title: 'Research: Azure Security — UAMI, CMEK, and TLS Enforcement'
status: Done
assignee: []
created_date: '2026-03-27 20:45'
updated_date: '2026-03-28 18:31'
labels:
  - research
  - azure
  - security
  - uami
  - cmek
  - tls
dependencies: []
references:
  - >-
    https://learn.microsoft.com/en-us/entra/identity/managed-identities-azure-resources/overview
  - 'https://learn.microsoft.com/en-us/azure/key-vault/keys/byok-specification'
  - >-
    https://learn.microsoft.com/en-us/azure/virtual-machines/disk-encryption-overview
parent_task_id: TASK-1
priority: high
---

## Description

<!-- SECTION:DESCRIPTION:BEGIN -->
Research Azure security requirements for the Kafka Lab: User Assigned Managed Identities (UAMI), Customer Managed Keys (CMEK), and TLS enforcement — as mandated by the project's Azure environment instructions.

## Goals
- Understand UAMI provisioning and assignment to Azure VMs hosting Confluent components
- Research Azure Key Vault + Disk Encryption Set configuration for CMEK on managed disks
- Understand how to provision one Key Vault key per resource (as required by compliance policy)
- Research TLS 1.2+ configuration for Kafka inter-broker, client, and ZooKeeper communication
- Research RBAC role assignments for UAMIs: Key Vault Crypto User, Storage Blob Data Contributor, etc.

## Key Questions
- How many UAMIs are needed, and what is the assignment strategy (one per VM? one per cluster?)?
- How is CMEK applied to Azure managed disks via Disk Encryption Sets?
- What is the Key Vault configuration required for CMK-based disk encryption?
- How is TLS configured between Confluent components (SSL listeners, ZooKeeper TLS)?

## Primary References (from README)
- https://learn.microsoft.com/en-us/entra/identity/managed-identities-azure-resources/overview
- https://learn.microsoft.com/en-us/azure/developer/terraform/overview-azapi-provider
<!-- SECTION:DESCRIPTION:END -->

## Acceptance Criteria
<!-- AC:BEGIN -->
- [x] #1 UAMI provisioning and assignment pattern for each VM type documented
- [x] #2 Key Vault + CMEK configuration for managed disks documented (one key per resource)
- [x] #3 Disk encryption set (DES) configuration for Azure managed disks documented
- [x] #4 TLS 1.2 enforcement approach for Kafka inter-broker and client communication documented
- [x] #5 Least-privilege RBAC role assignments for each UAMI documented
- [x] #6 Research doc created in backlog/docs covering: summary, key findings, architecture decisions, configuration reference, risks, and references
<!-- AC:END -->

## Implementation Plan

<!-- SECTION:PLAN:BEGIN -->
### Documentation Output

Publish findings via `backlog-document_create` with title: **Azure Security UAMI CMEK TLS Research**

The doc must cover:

- UAMI provisioning and assignment strategy (per VM, per cluster, per workflow)
- Key Vault + CMEK configuration for managed disks (one key per resource)
- Disk Encryption Set (DES) configuration
- TLS 1.2+ enforcement for Kafka inter-broker, client, and ZooKeeper communication
- Confluent SSL listener configuration
- Least-privilege RBAC role assignments per UAMI

Follow the standard research doc structure: Summary → Key Findings → Architecture Decisions → Configuration Reference → Risks and Open Questions → References
<!-- SECTION:PLAN:END -->

## Final Summary

<!-- SECTION:FINAL_SUMMARY:BEGIN -->
## Research Complete: Azure Security — UAMI, CMEK, and TLS Enforcement

### Deliverable
Published comprehensive research document **doc-10 — Azure Security UAMI CMEK TLS Research** to backlog/docs.

### Key Decisions Documented
1. **UAMI Strategy**: 9 UAMIs total (3 regions × 3 workflows: kafka-broker, zookeeper, DES) — one UAMI per workflow per region
2. **CMEK Strategy**: One Key Vault key + one Disk Encryption Set per managed disk; one Key Vault per region (Premium SKU, RBAC mode)
3. **TLS Strategy**: mTLS everywhere — Kafka inter-broker (SSL listener on :9093), ZooKeeper client+quorum TLS, TLS 1.2 minimum with TLS 1.3 preferred
4. **RBAC Roles**: Key Vault Crypto Service Encryption User for DES; Key Vault Secrets User for broker/ZK UAMIs

### Configuration References Included
- Terraform AzAPI HCL for UAMI, Key Vault, Key Vault Keys, DES, RBAC role assignments, and VM with CMEK disks
- Confluent `server.properties` for broker SSL/TLS and ZooKeeper mTLS
- ZooKeeper `zookeeper.properties` for server-side TLS
- RBAC role assignment summary table

### Open Questions Flagged
- ZooKeeper disk count (OS only vs OS + data)
- Certificate authority choice (self-signed CA vs HashiCorp Vault PKI vs Azure Key Vault certs)
- Key Vault Private Endpoint dependency on networking module
- Java version confirmation for TLS 1.3 support
<!-- SECTION:FINAL_SUMMARY:END -->

## Definition of Done
<!-- DOD:BEGIN -->
- [x] #1 Research findings published to backlog/docs via backlog-document_create
<!-- DOD:END -->
