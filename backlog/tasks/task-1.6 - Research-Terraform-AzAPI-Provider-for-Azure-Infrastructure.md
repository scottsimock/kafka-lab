---
id: TASK-1.6
title: 'Research: Terraform AzAPI Provider for Azure Infrastructure'
status: To Do
assignee: []
created_date: '2026-03-27 20:44'
updated_date: '2026-03-28 18:13'
labels:
  - research
  - terraform
  - azapi
  - infrastructure
dependencies: []
references:
  - >-
    https://learn.microsoft.com/en-us/azure/developer/terraform/overview-azapi-provider
  - 'https://registry.terraform.io/providers/azure/azapi/latest/docs'
parent_task_id: TASK-1
priority: high
---

## Description

<!-- SECTION:DESCRIPTION:BEGIN -->
Research the Terraform AzAPI provider to understand how it differs from the azurerm provider and how to use it for provisioning all Azure infrastructure required by the Kafka Lab.

## Goals
- Understand when to use AzAPI vs azurerm (latest Azure API features not yet in azurerm)
- Map required infrastructure resources to AzAPI resource types
- Research AzAPI resource definitions for: VMs, VNets, NSGs, Route Tables, Key Vault (CMEK), UAMI, Managed Disks, Proximity Placement Groups
- Understand AzAPI data sources and dynamic resource references
- Research Terraform state management with Azure Blob Storage backend

## Key Questions
- Which resources in the lab are best handled by AzAPI vs azurerm?
- How does AzAPI handle API version pinning, and how frequently should it be updated?
- What are AzAPI's limitations compared to azurerm for this use case?

## Primary References (from README)
- https://learn.microsoft.com/en-us/azure/developer/terraform/overview-azapi-provider
<!-- SECTION:DESCRIPTION:END -->

## Acceptance Criteria
<!-- AC:BEGIN -->
- [ ] #1 AzAPI provider resource coverage mapped to required Azure resources
- [ ] #2 AzAPI vs azurerm provider decision matrix documented
- [ ] #3 Required AzAPI resource types identified for VMs, VNets, Key Vault, UAMI, and CMEK
- [ ] #4 Terraform state backend configuration for Azure Blob Storage documented
- [ ] #5 Research doc created in backlog/docs covering: summary, key findings, architecture decisions, configuration reference, risks, and references
<!-- AC:END -->

## Implementation Plan

<!-- SECTION:PLAN:BEGIN -->
### Documentation Output

Publish findings via `backlog-document_create` with title: **Terraform AzAPI Provider Research**

The doc must cover:

- AzAPI vs azurerm provider decision matrix
- AzAPI resource type mapping for all required Azure resources (VMs, VNets, NSGs, Key Vault, UAMI, Managed Disks)
- API version pinning strategy
- AzAPI data sources and dynamic resource references
- Terraform state backend configuration for Azure Blob Storage
- Provider limitations and workarounds

Follow the standard research doc structure: Summary → Key Findings → Architecture Decisions → Configuration Reference → Risks and Open Questions → References
<!-- SECTION:PLAN:END -->

## Definition of Done
<!-- DOD:BEGIN -->
- [ ] #1 Research findings published to backlog/docs via backlog-document_create
<!-- DOD:END -->
