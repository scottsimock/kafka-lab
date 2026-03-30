---
id: TASK-28.10
title: SP1.006 — Network Security Group Module
status: Done
assignee:
  - tester-1
created_date: '2026-03-30 16:40'
updated_date: '2026-03-30 19:32'
labels:
  - story
milestone: m-1
dependencies:
  - TASK-28.1
references:
  - terraform/modules/network-security-group/
documentation:
  - doc-10
parent_task_id: TASK-28
priority: medium
ordinal: 1006
---

## Description

<!-- SECTION:DESCRIPTION:BEGIN -->
Create a reusable Terraform module at terraform/modules/network-security-group/ that provisions an NSG using azapi_resource with type Microsoft.Network/networkSecurityGroups@2024-05-01. The module accepts name, location, resource_group_id, security_rules (list of objects with: name, priority, direction, access, protocol, source_port_range, destination_port_range, source_address_prefix or source_address_prefixes, destination_address_prefix or destination_address_prefixes, description), subnet_id, and tags.

Security rules are defined inline within the NSG resource body as the securityRules property. The module also creates a subnet-NSG association using azapi_update_resource on the subnet to set the networkSecurityGroup property, or uses a separate azapi_resource for Microsoft.Network/virtualNetworks/subnets to associate the NSG.

Every NSG includes a terminal Deny-All-Inbound rule at priority 4096 automatically appended by the module (callers do not need to specify it).

Outputs: nsg_id, nsg_name.
<!-- SECTION:DESCRIPTION:END -->

## Acceptance Criteria
<!-- AC:BEGIN -->
- [x] #1 Module directory exists at terraform/modules/network-security-group/ with main.tf, variables.tf, outputs.tf, versions.tf
- [x] #2 versions.tf declares azapi provider >= 2.0
- [x] #3 main.tf uses azapi_resource with type Microsoft.Network/networkSecurityGroups@2024-05-01
- [x] #4 Module accepts name, location, resource_group_id, security_rules, subnet_id, and tags as input variables
- [x] #5 security_rules variable is a list of objects supporting name, priority, direction, access, protocol, port ranges, source/destination address prefixes, and description
- [x] #6 Module automatically appends a Deny-All-Inbound rule at priority 4096 to every NSG
- [x] #7 Module creates subnet-to-NSG association so the NSG is attached to the specified subnet
- [x] #8 Outputs include nsg_id and nsg_name
- [x] #9 terraform validate passes in terraform/environments/dev/
<!-- AC:END -->

## Implementation Notes

<!-- SECTION:NOTES:BEGIN -->
## [TL] 2026-03-30T19:26:00Z
- Assigned to coder-1 (Wave 2, priority 3)
- VNet module committed, main.tf safe to modify
- Unlocks TASK-28.8 (NSG Instances)

## [Coder] 2026-03-30T19:35:00Z
- Created terraform/modules/network-security-group/ with main.tf, variables.tf, outputs.tf, versions.tf
- azapi_resource.main provisions NSG with type Microsoft.Network/networkSecurityGroups@2024-05-01
- security_rules variable supports all port/address prefix variants with optional fields
- Deny-All-Inbound rule at priority 4096 auto-appended via concat()
- azapi_update_resource.subnet_nsg_association attaches NSG to specified subnet
- Outputs: nsg_id, nsg_name
- terraform fmt -recursive: formatted main.tf alignment
- terraform validate: Success
- Committed: feat(SP1.006): network security group module (f5cb574)

## [Tester] 2026-03-30T19:45:00Z

### Review: TASK-28.10 — SP1.006 Network Security Group Module

**Verification Checklist**
- [x] NSG uses azapi_resource type Microsoft.Network/networkSecurityGroups@2024-05-01
- [x] security_rules variable is list(object) with all required optional fields
- [x] Deny-All-Inbound rule at priority 4096 auto-appended via concat()
- [x] azapi_update_resource used for subnet-NSG association
- [x] Outputs: nsg_id and nsg_name present with descriptions
- [x] // comments only (no #)
- [x] All variables have descriptions

**Score Breakdown**

| Category | Weight | Score | Notes |
|---|---|---|---|
| Acceptance Criteria | 30 | 30 | All 9 AC items fully met |
| Tests | 25 | 25 | terraform fmt -check: pass; terraform validate: pass |
| Code Quality | 20 | 20 | Clean structure, // comments, snake_case, section headers, explicit depends_on |
| Documentation | 15 | 15 | All variables and outputs have descriptions |
| Dependencies | 10 | 10 | No broken imports; azapi provider correctly declared; VNet dependency present |

**Total: 100/100 — PASS**

All acceptance criteria met. Module is complete and correct.
<!-- SECTION:NOTES:END -->
