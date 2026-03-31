---
id: TASK-34.7
title: SP8.003 — Cross-Region Private DNS Zone Links
status: To Do
assignee: []
created_date: '2026-03-30 16:50'
updated_date: '2026-03-31 21:59'
labels:
  - story
milestone: m-7
dependencies:
  - TASK-34.6
references:
  - terraform/modules/private-dns-zone/
documentation:
  - doc-10
parent_task_id: TASK-34
priority: medium
ordinal: 7003
---

## Description

<!-- SECTION:DESCRIPTION:BEGIN -->
Extend Private DNS zone VNet links to include the mexicocentral and canadaeast VNets. Update the existing DNS zone instances to link to all 3 VNets, ensuring private endpoint DNS resolution works cross-region. Per doc-10.
<!-- SECTION:DESCRIPTION:END -->

## Acceptance Criteria
<!-- AC:BEGIN -->
- [ ] #1 Private DNS zones linked to mexicocentral and canadaeast VNets
- [ ] #2 privatelink.blob.core.windows.net linked to all 3 VNets
- [ ] #3 privatelink.vaultcore.azure.net linked to all 3 VNets
- [ ] #4 DNS resolution works from all regions for private endpoints
- [ ] #5 terraform validate passes
<!-- AC:END -->
