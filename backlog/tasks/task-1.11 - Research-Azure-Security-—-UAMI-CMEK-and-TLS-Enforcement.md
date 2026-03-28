---
id: TASK-1.11
title: 'Research: Azure Security — UAMI, CMEK, and TLS Enforcement'
status: To Do
assignee: []
created_date: '2026-03-27 20:45'
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
- [ ] #1 UAMI provisioning and assignment pattern for each VM type documented
- [ ] #2 Key Vault + CMEK configuration for managed disks documented (one key per resource)
- [ ] #3 Disk encryption set (DES) configuration for Azure managed disks documented
- [ ] #4 TLS 1.2 enforcement approach for Kafka inter-broker and client communication documented
- [ ] #5 Least-privilege RBAC role assignments for each UAMI documented
<!-- AC:END -->
