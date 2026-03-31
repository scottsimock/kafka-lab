---
id: TASK-35.4
title: SP9.004 — Azure Front Door Configuration
status: To Do
assignee: []
created_date: '2026-03-30 16:51'
updated_date: '2026-03-31 21:58'
labels:
  - story
milestone: m-8
dependencies: []
references:
  - terraform/
documentation:
  - doc-16
parent_task_id: TASK-35
priority: high
ordinal: 8004
---

## Description

<!-- SECTION:DESCRIPTION:BEGIN -->
Provision Azure Front Door as the public ingress layer for the web application. Configure TLS termination, backend pool pointing to the Function App, HTTP-to-HTTPS redirect, WAF policy, and health probes. Front Door is the only resource with public internet access per azure-environment requirements. Let's Encrypt certs stored in Key Vault.
<!-- SECTION:DESCRIPTION:END -->

## Acceptance Criteria
<!-- AC:BEGIN -->
- [ ] #1 Azure Front Door provisioned via Terraform for web app ingress
- [ ] #2 TLS termination configured with Let's Encrypt certificate
- [ ] #3 Backend pool points to Function App private endpoint
- [ ] #4 HTTP to HTTPS redirect configured
- [ ] #5 WAF policy attached with OWASP managed rules
- [ ] #6 Health probe configured for backend monitoring
- [ ] #7 terraform validate passes
<!-- AC:END -->
