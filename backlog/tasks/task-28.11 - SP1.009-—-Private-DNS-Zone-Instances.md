---
id: TASK-28.11
title: SP1.009 — Private DNS Zone Instances
status: Done
assignee:
  - tester-1
created_date: '2026-03-30 16:40'
updated_date: '2026-03-30 19:40'
labels:
  - story
milestone: m-1
dependencies:
  - TASK-28.6
  - TASK-28.5
references:
  - terraform/modules/private-dns-zone/
documentation:
  - doc-10
parent_task_id: TASK-28
priority: medium
ordinal: 1009
---

## Description

<!-- SECTION:DESCRIPTION:BEGIN -->
Using the private-dns-zone module from TASK-28.6 (SP1.008), instantiate Private DNS zones for Azure PaaS services that will use private endpoints. Create two zones in the root module using for_each over a local map:

1. privatelink.blob.core.windows.net — for Azure Blob Storage private endpoints
2. privatelink.vaultcore.azure.net — for Azure Key Vault private endpoints

Link each zone to the southcentralus VNet (klc-vnet-scus) with autoregistration disabled. Per doc-10, these zones are global resources and A records are automatically created when private endpoints with DNS zone groups are provisioned (in TASK-28.9).

For the dev environment (single region), each zone links to only klc-vnet-scus. Multi-region VNet links will be added in later sprints when additional regions are deployed.

Expose DNS zone IDs as outputs from the root module for consumption by TASK-28.9 (private endpoint creation).
<!-- SECTION:DESCRIPTION:END -->

## Acceptance Criteria
<!-- AC:BEGIN -->
- [x] #1 Private DNS zone privatelink.blob.core.windows.net created via private-dns-zone module in root module
- [x] #2 Private DNS zone privatelink.vaultcore.azure.net created via private-dns-zone module in root module
- [x] #3 Both DNS zones linked to klc-vnet-scus VNet via VNet link resources
- [x] #4 VNet links have registrationEnabled set to false (autoregistration disabled)
- [x] #5 DNS zone instances defined using for_each over a local map of zone names
- [x] #6 Outputs expose the DNS zone IDs for use by private endpoint tasks (TASK-28.9)
- [x] #7 terraform validate passes in terraform/environments/dev/
<!-- AC:END -->

## Implementation Notes

<!-- SECTION:NOTES:BEGIN -->
## [TL] 2026-03-30T19:42:00Z
- Assigned to coder-1 (Wave 3)
- Dependencies 28.6 and 28.5 both Done
- Modifies main.tf: adds DNS zone instances via for_each

## [Coder] 2026-03-30T20:00:00Z
- Appended Private DNS Zones section to terraform/environments/dev/main.tf
- Added locals.private_dns_zones map: blob → privatelink.blob.core.windows.net, vault → privatelink.vaultcore.azure.net
- Added module.private_dns_zones with for_each over local map, linked to klc-vnet-scus via link-scus
- Added output private_dns_zone_ids to terraform/environments/dev/outputs.tf
- terraform fmt -recursive and terraform validate both pass
- Committed: feat(SP1.009): private dns zone instances

## [Tester] 2026-03-30T20:15:00Z

### Score Breakdown

| Category | Weight | Score | Notes |
|---|---|---|---|
| Acceptance Criteria | 30 | 30 | All 7 AC met: both zones exist, for_each over local map, linked to klc-vnet-scus, registrationEnabled=false (enforced in module), output exposes zone IDs as map |
| Tests | 25 | 25 | terraform fmt -check: PASS (exit 0). terraform validate: PASS ("Success! The configuration is valid.") |
| Code Quality | 20 | 20 | Clean section header comment, snake_case locals, concise for_each pattern |
| Documentation | 15 | 15 | output "private_dns_zone_ids" has description |
| Dependencies | 10 | 10 | Module source ../../modules/private-dns-zone resolves; dns_zone_id output referenced correctly; vnet_scus.vnet_id dependency satisfied |

**Total: 100/100 — PASS (threshold 90%)**
<!-- SECTION:NOTES:END -->
