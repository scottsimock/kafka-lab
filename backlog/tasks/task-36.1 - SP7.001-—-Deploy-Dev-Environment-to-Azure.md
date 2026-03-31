---
id: TASK-36.1
title: SP7.001 — Deploy Dev Environment to Azure
status: In Progress
assignee:
  - Drexl
created_date: '2026-03-31 22:00'
updated_date: '2026-03-31 22:22'
labels:
  - story
milestone: m-9
dependencies: []
references:
  - terraform/environments/
  - ansible/
parent_task_id: TASK-36
priority: high
ordinal: 6501
---

## Description

<!-- SECTION:DESCRIPTION:BEGIN -->
Execute Terraform apply for the dev environment targeting southcentralus single region (Zone 1). Run Ansible provisioning for the full Confluent Kafka stack (ZooKeeper, brokers, Schema Registry, Kafka Connect). Verify all VMs are healthy, Kafka cluster is formed, topics are creatable, and the web application Function App is deployed and reachable via its private endpoint.
<!-- SECTION:DESCRIPTION:END -->

## Acceptance Criteria
<!-- AC:BEGIN -->
- [ ] #1 Terraform apply completes successfully for dev environment in southcentralus
- [ ] #2 All VMs provisioned and passing health checks (SSH accessible via private IP)
- [ ] #3 Ansible provisioning completes for ZooKeeper, Kafka brokers, Schema Registry, Kafka Connect
- [ ] #4 Kafka cluster forms successfully with all brokers in ISR
- [ ] #5 Test topic can be created and messages produced/consumed
- [ ] #6 Web application Function App deployed and responding on private endpoint
- [ ] #7 Key Vault secrets accessible by Function App UAMI
- [ ] #8 All resources tagged with environment=dev
<!-- AC:END -->

## Implementation Notes

<!-- SECTION:NOTES:BEGIN -->
## [Drexl] 2026-04-01T00:00:00Z
- Wired Function App module into dev main.tf (was defined but never instantiated)
- Added privatelink.azurewebsites.net DNS zone + private endpoint for Function App
- Fixed function-app module: added response_export_values for defaultHostName output
- Extended outputs.tf with 5 new Function App outputs
- Created ansible/inventory/dev-static.ini (static fallback for CI/local dev)
- Created ansible/playbooks/verify-dev.yml (dev verification without SASL_SSL)
- Created scripts/deploy-dev.sh (full orchestration: terraform → ansible → verify)
- Created docs/deploy-dev.md (deployment guide)
- Terraform validate: PASS
- All YAML syntax: PASS
- Shell script syntax: PASS
<!-- SECTION:NOTES:END -->
