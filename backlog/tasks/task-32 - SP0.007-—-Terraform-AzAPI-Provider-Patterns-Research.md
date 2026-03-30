---
id: TASK-32
title: SP0.007 — Terraform AzAPI Provider Patterns Research
status: To Do
assignee: []
created_date: '2026-03-30 13:42'
labels:
  - research
milestone: m-0
dependencies: []
references:
  - >-
    https://learn.microsoft.com/en-us/azure/developer/terraform/overview-azapi-provider
priority: medium
ordinal: 7000
---

## Description

<!-- SECTION:DESCRIPTION:BEGIN -->
Research Terraform AzAPI provider best practices for provisioning Azure infrastructure. Cover resource definitions for VMs, VNets, NSGs, managed identities, Key Vault, and Blob Storage. Define module structure for the kafka-lab project.\n\nKey areas:\n- AzAPI provider vs AzureRM: when to use AzAPI, API version pinning\n- Resource definitions: azapi_resource for VMs, VNets, subnets, NSGs, NICs\n- Managed Identity provisioning: User Assigned Managed Identity per workflow\n- Key Vault provisioning with CMEK key generation\n- Blob Storage provisioning with private endpoint and CMEK\n- Module structure: modules/networking, modules/compute, modules/storage, modules/identity\n- State management: Azure Blob Storage backend\n- Environment separation: dev/staging/prod via .tfvars files\n- Preflight validation and plan/apply patterns\n- Output values for Ansible inventory generation\n\nExpected output: backlog document doc-SP0.007-terraform-azapi-patterns
<!-- SECTION:DESCRIPTION:END -->

## Acceptance Criteria
<!-- AC:BEGIN -->
- [ ] #1 AzAPI provider usage patterns documented with API version pinning strategy
- [ ] #2 Resource definition examples for VM, VNet, subnet, NSG, NIC using azapi_resource
- [ ] #3 Managed Identity provisioning pattern documented
- [ ] #4 Key Vault and CMEK key provisioning documented
- [ ] #5 Blob Storage with private endpoint provisioning documented
- [ ] #6 Module directory structure recommended for kafka-lab
- [ ] #7 State backend configuration documented
- [ ] #8 Environment separation via .tfvars documented
- [ ] #9 Terraform output values for Ansible inventory identified
- [ ] #10 All findings reference official AzAPI provider documentation
<!-- AC:END -->
