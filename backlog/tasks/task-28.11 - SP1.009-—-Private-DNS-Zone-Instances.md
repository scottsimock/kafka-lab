---
id: TASK-28.11
title: SP1.009 — Private DNS Zone Instances
status: To Do
assignee: []
created_date: '2026-03-30 16:40'
updated_date: '2026-03-30 16:40'
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
Using the private-dns-zone module from SP1.008, instantiate Private DNS zones for Azure PaaS services that will use private endpoints: privatelink.blob.core.windows.net (for Blob Storage) and privatelink.vaultcore.azure.net (for Key Vault). Link each zone to the southcentralus VNet (klc-vnet-scus).
<!-- SECTION:DESCRIPTION:END -->

## Acceptance Criteria
<!-- AC:BEGIN -->
- [ ] #1 Private DNS zone for privatelink.blob.core.windows.net created and linked to klc-vnet-scus
- [ ] #2 Private DNS zone for privatelink.vaultcore.azure.net created and linked to klc-vnet-scus
- [ ] #3 All DNS zones use the private-dns-zone module
- [ ] #4 terraform validate passes
<!-- AC:END -->
