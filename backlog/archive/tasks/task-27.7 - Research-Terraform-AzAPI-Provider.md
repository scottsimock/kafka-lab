---
id: TASK-27.7
title: 'Research: Terraform AzAPI Provider'
status: To Do
assignee: []
created_date: '2026-03-30 13:37'
labels:
  - research
  - SP0P1
milestone: m-0
dependencies: []
references:
  - >-
    https://learn.microsoft.com/en-us/azure/developer/terraform/overview-azapi-provider
  - 'https://registry.terraform.io/providers/azure/azapi/latest/docs'
  - 'https://learn.microsoft.com/en-us/azure/developer/terraform/'
documentation:
  - doc-SP0.007-terraform-azapi-provider
parent_task_id: TASK-27
priority: high
ordinal: 7000
---

## Description

<!-- SECTION:DESCRIPTION:BEGIN -->
Research the Terraform AzAPI provider for provisioning Azure infrastructure. The kafka-lab project uses AzAPI instead of AzureRM for full ARM API coverage and preview feature support. Cover provider capabilities, resource lifecycle, and module patterns.

Focus areas:
- AzAPI provider architecture and how it maps to ARM REST APIs
- Resource type syntax (azapi_resource, azapi_update_resource, azapi_resource_action)
- API version selection and preview feature access
- Comparison with AzureRM: when AzAPI is preferred, migration path
- Module structure for reusable multi-region infrastructure
- State management and backend configuration for team environments
<!-- SECTION:DESCRIPTION:END -->

## Acceptance Criteria
<!-- AC:BEGIN -->
- [ ] #1 Document explains AzAPI provider architecture: ARM REST API mapping, resource types, API versions
- [ ] #2 Document compares AzAPI vs AzureRM provider with tradeoffs and when to use each
- [ ] #3 Document covers resource lifecycle: create, read, update, delete, import, and preflight validation
- [ ] #4 Document covers module patterns for multi-region deployment using AzAPI
- [ ] #5 Document covers state management: backend configuration, locking, sensitive outputs
- [ ] #6 Document includes example resource definitions for VM, VNet, and Key Vault using AzAPI
- [ ] #7 All findings cite official Microsoft Learn and HashiCorp documentation with URLs
- [ ] #8 Executive summary of 300 words or fewer leads the document
<!-- AC:END -->
