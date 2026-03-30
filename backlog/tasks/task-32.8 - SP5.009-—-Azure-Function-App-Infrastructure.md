---
id: TASK-32.8
title: SP5.009 — Azure Function App Infrastructure
status: To Do
assignee: []
created_date: '2026-03-30 16:46'
updated_date: '2026-03-30 16:47'
labels:
  - story
milestone: m-5
dependencies:
  - TASK-28.5
references:
  - terraform/modules/function-app/
documentation:
  - doc-16
  - doc-14
parent_task_id: TASK-32
priority: high
ordinal: 5009
---

## Description

<!-- SECTION:DESCRIPTION:BEGIN -->
Create a Terraform module at terraform/modules/function-app/ that provisions an Azure Function App for the Next.js web application. Use Premium plan EP1 for VNet integration capability. Configure VNet integration to snet-web-app subnet, UAMI assignment, application settings with Key Vault references for Kafka credentials, and custom handler for Next.js standalone output. Per doc-16.
<!-- SECTION:DESCRIPTION:END -->

## Acceptance Criteria
<!-- AC:BEGIN -->
- [ ] #1 Terraform module at terraform/modules/function-app/ provisions Azure Function App
- [ ] #2 Function App uses Premium plan (EP1) for VNet integration
- [ ] #3 VNet integration configured to snet-web-app subnet
- [ ] #4 UAMI assigned to Function App for Key Vault access
- [ ] #5 Application settings include Kafka connection env vars (from Key Vault references)
- [ ] #6 Custom handler configured for Next.js standalone server
- [ ] #7 public_network_access disabled (accessed via Front Door only)
<!-- AC:END -->
