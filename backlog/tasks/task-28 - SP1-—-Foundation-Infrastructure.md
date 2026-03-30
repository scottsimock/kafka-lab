---
id: TASK-28
title: SP1 — Foundation Infrastructure
status: To Do
assignee: []
created_date: '2026-03-30 16:37'
updated_date: '2026-03-30 17:09'
labels:
  - sprint
milestone: m-1
dependencies: []
priority: high
ordinal: 1000
---

## Description

<!-- SECTION:DESCRIPTION:BEGIN -->
Foundation infrastructure sprint covering Terraform project structure, state backend, provider configuration, Key Vault with CMEK, User Assigned Managed Identities, Virtual Network with subnets for southcentralus Zone 1, Network Security Groups, and Private DNS zones. All resources deployed to resource group klc-rg-kafkalab-scus in southcentralus.
<!-- SECTION:DESCRIPTION:END -->

## Acceptance Criteria
<!-- AC:BEGIN -->
- [ ] #1 Terraform project structure is initialized with provider configuration, state backend, and versioned module layout under terraform/modules/
- [ ] #2 Key Vault module deployed with CMEK encryption and UAMI authentication in southcentralus
- [ ] #3 Virtual Network module provisions VNet with all required subnets in southcentralus Zone 1
- [ ] #4 Private DNS Zone and Private Endpoint modules are functional and linked to the VNet
- [ ] #5 NSG module and per-subnet NSG instances enforce network security rules across all subnets
<!-- AC:END -->
