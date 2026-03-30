---
id: TASK-28.6
title: SP1.008 — Private DNS Zone Module
status: Done
assignee:
  - tester-2
created_date: '2026-03-30 16:40'
updated_date: '2026-03-30 19:35'
labels:
  - story
milestone: m-1
dependencies:
  - TASK-28.1
references:
  - terraform/modules/private-dns-zone/
documentation:
  - doc-10
parent_task_id: TASK-28
priority: medium
ordinal: 1008
---

## Description

<!-- SECTION:DESCRIPTION:BEGIN -->
Create a reusable Terraform module at terraform/modules/private-dns-zone/ that provisions an Azure Private DNS Zone using azapi_resource with type Microsoft.Network/privateDnsZones@2020-06-01 and links it to one or more VNets via azapi_resource with type Microsoft.Network/privateDnsZones/virtualNetworkLinks@2020-06-01.

The module accepts zone_name, resource_group_id, vnet_links (map of link name to VNet ID for multi-VNet support), and tags. Use for_each on the vnet_links map to create one VNet link per entry. Autoregistration must be disabled (registrationEnabled: false) on all Private DNS zone links for private endpoint zones — per doc-10, autoregistration is only appropriate for VM hostname zones.

The Private DNS zone is a global resource (not region-specific). The location property must be set to "global" in the azapi_resource body.

Outputs: dns_zone_id, dns_zone_name.
<!-- SECTION:DESCRIPTION:END -->

## Acceptance Criteria
<!-- AC:BEGIN -->
- [x] #1 Module directory exists at terraform/modules/private-dns-zone/ with main.tf, variables.tf, outputs.tf, versions.tf
- [x] #2 versions.tf declares azapi provider >= 2.0
- [x] #3 main.tf uses azapi_resource with type Microsoft.Network/privateDnsZones@2020-06-01
- [x] #4 Module creates VNet link via azapi_resource with type Microsoft.Network/privateDnsZones/virtualNetworkLinks@2020-06-01
- [x] #5 VNet link has registrationEnabled set to false (autoregistration disabled)
- [x] #6 Module accepts zone_name, resource_group_id, vnet_links (map of name to vnet_id), and tags as input variables
- [x] #7 vnet_links variable supports linking a single zone to multiple VNets via for_each
- [x] #8 Outputs include dns_zone_id and dns_zone_name
- [x] #9 terraform validate passes in terraform/environments/dev/
<!-- AC:END -->

## Implementation Notes

<!-- SECTION:NOTES:BEGIN -->
## [TL] 2026-03-30T19:28:00Z
- Assigned to coder-2 (Wave 2 final module)
- Module only, no main.tf changes
- Unlocks TASK-28.11

## [Coder] 2026-03-30T19:45:00Z
- Created terraform/modules/private-dns-zone/ with main.tf, variables.tf, outputs.tf, versions.tf
- azapi_resource "main": Microsoft.Network/privateDnsZones@2020-06-01, location=global
- azapi_resource "vnet_link": Microsoft.Network/privateDnsZones/virtualNetworkLinks@2020-06-01, for_each on vnet_links map, registrationEnabled=false
- All variables and outputs have descriptions, no trailing periods
- terraform fmt + terraform validate passed
- Committed: feat(SP1.008): private dns zone module

## [Tester] 2026-03-30T20:00:00Z

### Score Breakdown

| Category | Weight | Score | Notes |
|---|---|---|---|
| Acceptance Criteria | 30 | 30 | All 9 AC items checked: module exists, versions.tf with azapi>=2.0, correct resource types, VNet link with registrationEnabled=false, all variables present, for_each on vnet_links, both outputs |
| Tests | 25 | 25 | terraform fmt -check passed (exit 0); terraform validate passed (exit 0) |
| Code Quality | 20 | 20 | Clean HCL, // comments used consistently, snake_case throughout, section headers, no extraneous code |
| Documentation | 15 | 15 | All variables and outputs have descriptions, no trailing periods |
| Dependencies | 10 | 10 | No broken imports, depends_on correctly set, no regressions |

**Total: 100/100 — PASS**

### Checklist
- [x] type = "Microsoft.Network/privateDnsZones@2020-06-01" with location = "global"
- [x] VNet link type = "Microsoft.Network/privateDnsZones/virtualNetworkLinks@2020-06-01"
- [x] for_each used on vnet_links map
- [x] registrationEnabled = false
- [x] vnet_links variable is map(string)
- [x] Outputs: dns_zone_id and dns_zone_name
<!-- SECTION:NOTES:END -->
