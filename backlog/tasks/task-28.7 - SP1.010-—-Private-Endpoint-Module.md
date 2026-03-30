---
id: TASK-28.7
title: SP1.010 — Private Endpoint Module
status: Done
assignee:
  - tester-3
created_date: '2026-03-30 16:40'
updated_date: '2026-03-30 19:35'
labels:
  - story
milestone: m-1
dependencies:
  - TASK-28.1
  - TASK-28.5
references:
  - terraform/modules/private-endpoint/
documentation:
  - doc-10
  - doc-14
parent_task_id: TASK-28
priority: medium
ordinal: 1010
---

## Description

<!-- SECTION:DESCRIPTION:BEGIN -->
Create a reusable Terraform module at terraform/modules/private-endpoint/ that provisions an Azure Private Endpoint using azapi_resource with type Microsoft.Network/privateEndpoints@2024-05-01. The module creates a private endpoint connected to the target resource via privateLinkServiceConnections, and creates a privateDnsZoneGroups child resource (Microsoft.Network/privateEndpoints/privateDnsZoneGroups@2024-05-01) for automatic DNS A record registration.

Module inputs:
- name: private endpoint name
- location: Azure region
- resource_group_id: target resource group
- subnet_id: subnet for the PE NIC (typically snet-private-endpoints)
- target_resource_id: the Azure resource to connect to (e.g., storage account ID, key vault ID)
- group_ids: list of sub-resource group IDs (e.g., ["blob"], ["vault"])
- dns_zone_ids: map of group name to Private DNS zone ID for A record auto-registration
- tags: resource tags

The privateLinkServiceConnections block links the PE to the target resource using the specified group_ids. The privateDnsZoneGroups child resource must reference the correct Private DNS zone to enable automatic A record creation when the PE is provisioned.

Outputs: private_endpoint_id, private_endpoint_name, network_interface_id.

This module depends on TASK-28.5 (VNet with subnets) because the PE NIC is placed in snet-private-endpoints.
<!-- SECTION:DESCRIPTION:END -->

## Acceptance Criteria
<!-- AC:BEGIN -->
- [x] #1 Module directory exists at terraform/modules/private-endpoint/ with main.tf, variables.tf, outputs.tf, versions.tf
- [x] #2 versions.tf declares azapi provider >= 2.0
- [x] #3 main.tf uses azapi_resource with type Microsoft.Network/privateEndpoints@2024-05-01
- [x] #4 Module accepts name, location, resource_group_id, subnet_id, target_resource_id, group_ids (list of strings), dns_zone_ids (map of group name to DNS zone ID), and tags as input variables
- [x] #5 Private endpoint body includes privateLinkServiceConnections with groupIds and target resource
- [x] #6 Module creates privateDnsZoneGroups child resource via azapi_resource with type Microsoft.Network/privateEndpoints/privateDnsZoneGroups@2024-05-01 for automatic DNS A record registration
- [x] #7 Outputs include private_endpoint_id, private_endpoint_name, and network_interface_id
- [x] #8 response_export_values extracts the private endpoint NIC and IP information
- [x] #9 terraform validate passes in terraform/environments/dev/
<!-- AC:END -->

## Implementation Notes

<!-- SECTION:NOTES:BEGIN -->
## [TL] 2026-03-30T19:28:00Z
- Assigned to coder-3 (Wave 3 module-only)
- Module only, no main.tf changes
- Dependency 28.5 Done

## [Coder] 2026-03-30T20:00:00Z
- Created terraform/modules/private-endpoint/ with main.tf, variables.tf, outputs.tf, versions.tf
- azapi_resource.main: Microsoft.Network/privateEndpoints@2024-05-01 with privateLinkServiceConnections and response_export_values for NIC extraction
- azapi_resource.dns_zone_group: Microsoft.Network/privateEndpoints/privateDnsZoneGroups@2024-05-01 with dynamic for-expression over dns_zone_ids map
- All 8 variables declared with descriptions; 3 outputs declared
- terraform fmt: no changes needed
- terraform validate: Success
- Committed: feat(SP1.010): private endpoint module (12bcdf8)

## [Tester] 2026-03-30T20:10:00Z
- Score: 100/100 — PASS
- terraform fmt -check: clean (exit 0)
- terraform validate: Success
- All 9 AC items verified
- Verification checklist: all 6 items confirmed
- Acceptance Criteria 30/30, Tests 25/25, Code Quality 20/20, Documentation 15/15, Dependencies 10/10
<!-- SECTION:NOTES:END -->
