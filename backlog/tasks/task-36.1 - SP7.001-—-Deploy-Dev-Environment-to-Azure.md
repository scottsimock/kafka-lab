---
id: TASK-36.1
title: SP7.001 — Deploy Dev Environment to Azure
status: To Do
assignee: []
created_date: '2026-03-31 22:00'
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
