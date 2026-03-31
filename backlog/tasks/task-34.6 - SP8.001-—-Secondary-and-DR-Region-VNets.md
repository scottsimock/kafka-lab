---
id: TASK-34.6
title: SP8.001 — Secondary and DR Region VNets
status: To Do
assignee: []
created_date: '2026-03-30 16:50'
updated_date: '2026-03-31 21:59'
labels:
  - story
milestone: m-7
dependencies: []
references:
  - terraform/modules/virtual-network/
documentation:
  - doc-10
parent_task_id: TASK-34
priority: high
ordinal: 7001
---

## Description

<!-- SECTION:DESCRIPTION:BEGIN -->
Provision VNets with subnets and NSGs for mexicocentral (klc-vnet-mxc, 10.2.0.0/16) and canadaeast (klc-vnet-cae, 10.3.0.0/16). Reuse the virtual-network and NSG modules from SP1. Each VNet gets the same 7-subnet layout. NSG rules adjusted for cross-region broker CIDRs. Per doc-10.
<!-- SECTION:DESCRIPTION:END -->

## Acceptance Criteria
<!-- AC:BEGIN -->
- [ ] #1 VNet klc-vnet-mxc created in mexicocentral with 10.2.0.0/16
- [ ] #2 VNet klc-vnet-cae created in canadaeast with 10.3.0.0/16
- [ ] #3 Both VNets have identical 7-subnet layout matching southcentralus
- [ ] #4 Subnet CIDRs use 10.2.x.0/24 and 10.3.x.0/24 respectively
- [ ] #5 NSGs created and associated with each subnet per region
- [ ] #6 terraform validate passes
<!-- AC:END -->
