---
id: TASK-28.5
title: SP1.005 — Virtual Network Module with Subnets
status: Done
assignee:
  - tester-2
created_date: '2026-03-30 16:40'
updated_date: '2026-03-30 19:28'
labels:
  - story
milestone: m-1
dependencies:
  - TASK-28.1
references:
  - terraform/modules/virtual-network/
documentation:
  - doc-10
parent_task_id: TASK-28
priority: high
ordinal: 1005
---

## Description

<!-- SECTION:DESCRIPTION:BEGIN -->
Create a reusable Terraform module at terraform/modules/virtual-network/ that provisions an Azure VNet using azapi_resource with type Microsoft.Network/virtualNetworks@2024-05-01. The module accepts name, location, resource_group_id, address_space (list of strings), subnets (map of objects with address_prefix and optional properties), and tags.

Subnets are defined inline within the VNet resource body (not as separate azapi_resource blocks), as the ARM API expects subnets as a child property of virtualNetworks.

For the dev environment, instantiate in the root module as klc-vnet-scus with address space 10.1.0.0/16 and these 7 subnets per doc-10:
- snet-kafka-brokers: 10.1.1.0/24
- snet-zookeeper: 10.1.2.0/24
- snet-schema-registry: 10.1.3.0/24
- snet-connect: 10.1.4.0/24
- snet-web-app: 10.1.5.0/24
- snet-private-endpoints: 10.1.6.0/24 (privateEndpointNetworkPolicies: NetworkSecurityGroupEnabled)
- snet-management: 10.1.7.0/24

Outputs: vnet_id, vnet_name, subnet_ids (map of subnet name to subnet resource ID).

Use response_export_values to extract subnet IDs from the API response properties.subnets array.
<!-- SECTION:DESCRIPTION:END -->

## Acceptance Criteria
<!-- AC:BEGIN -->
- [ ] #1 Module directory exists at terraform/modules/virtual-network/ with main.tf, variables.tf, outputs.tf, versions.tf
- [ ] #2 versions.tf declares azapi provider >= 2.0
- [ ] #3 main.tf uses azapi_resource with type Microsoft.Network/virtualNetworks@2024-05-01
- [ ] #4 Module accepts name, location, resource_group_id, address_space, subnets, and tags as input variables
- [ ] #5 Subnets are defined inline within the VNet resource body (not as separate resources)
- [ ] #6 Root module instantiates VNet as klc-vnet-scus with 10.1.0.0/16 address space
- [ ] #7 All 7 subnets created: snet-kafka-brokers (10.1.1.0/24), snet-zookeeper (10.1.2.0/24), snet-schema-registry (10.1.3.0/24), snet-connect (10.1.4.0/24), snet-web-app (10.1.5.0/24), snet-private-endpoints (10.1.6.0/24), snet-management (10.1.7.0/24)
- [ ] #8 snet-private-endpoints has privateEndpointNetworkPolicies set to NetworkSecurityGroupEnabled
- [ ] #9 Outputs include vnet_id, vnet_name, and subnet_ids (map of subnet name to resource ID)
- [ ] #10 terraform validate passes in terraform/environments/dev/
<!-- AC:END -->

## Implementation Notes

<!-- SECTION:NOTES:BEGIN -->
## [TL] 2026-03-30T19:23:00Z
- Assigned to coder-2 (Wave 2, priority 2)
- TASK-28.3 committed, main.tf safe to modify
- Critical path: unlocks TASK-28.8 and TASK-28.11

## [Coder] 2026-03-30T19:30:00Z
- Created terraform/modules/virtual-network/ with main.tf, variables.tf, outputs.tf, versions.tf
- azapi_resource with type Microsoft.Network/virtualNetworks@2024-05-01
- Subnets defined inline in VNet body via for expression
- response_export_values used to extract subnet IDs from API response
- subnet_ids output maps subnet name to resource ID via output.properties.subnets
- snet-private-endpoints has privateEndpointNetworkPolicies=NetworkSecurityGroupEnabled
- Appended vnet_scus module call to terraform/environments/dev/main.tf
- Added vnet_id and subnet_ids outputs to terraform/environments/dev/outputs.tf
- terraform fmt and terraform validate both passed
- Committed as feat(SP1.005): virtual network module with subnets

## [Tester] 2026-03-30T19:35:00Z

### Review: SP1.005 — Virtual Network Module with Subnets

**Checklist Results:**
- [x] versions.tf declares azapi provider >= 2.0
- [x] main.tf uses azapi_resource with type Microsoft.Network/virtualNetworks@2024-05-01
- [x] Subnets defined inline in VNet body via for expression (not separate resources)
- [x] response_export_values includes "properties.subnets"
- [x] All 7 subnets present with correct CIDRs
- [x] snet-private-endpoints has privateEndpointNetworkPolicies = "NetworkSecurityGroupEnabled"
- [x] Root module instantiates VNet as klc-vnet-scus with 10.1.0.0/16
- [x] subnet_ids output maps subnet name to resource ID
- [x] // comments only (no # comments)
- [x] All variables and outputs have descriptions

**Acceptance Criteria (10/10 met):**
All AC items fully satisfied.

**Score Breakdown:**
| Category | Weight | Score | Notes |
|---|---|---|---|
| Acceptance Criteria | 30 | 30 | All 10 AC items met |
| Tests | 25 | 25 | terraform fmt -check and terraform validate both pass |
| Code Quality | 20 | 20 | Clean structure, correct use of coalesce(), section headers, snake_case |
| Documentation | 15 | 15 | All variables and outputs have descriptions |
| Dependencies | 10 | 10 | No broken references, module source paths correct |
| **Total** | **100** | **100** | |

**Result: PASS — 100% (threshold: 90%)**
Status set to Done.
<!-- SECTION:NOTES:END -->
