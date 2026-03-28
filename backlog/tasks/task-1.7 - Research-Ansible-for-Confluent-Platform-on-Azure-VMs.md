---
id: TASK-1.7
title: 'Research: Ansible for Confluent Platform on Azure VMs'
status: Done
assignee: []
created_date: '2026-03-27 20:44'
updated_date: '2026-03-28 18:24'
labels:
  - research
  - ansible
  - confluent
  - configuration-management
dependencies: []
references:
  - 'https://docs.confluent.io/ansible/current/overview.html'
  - >-
    https://docs.ansible.com/ansible/latest/collections/azure/azcollection/index.html
parent_task_id: TASK-1
priority: high
---

## Description

<!-- SECTION:DESCRIPTION:BEGIN -->
Research Ansible automation for Confluent Platform 7.x on Ubuntu 22.04 LTS Azure VMs, with a focus on the official Confluent Ansible collection (cp-ansible).

## Goals
- Research cp-ansible (Confluent's official Ansible collection) and its coverage of Platform 7.x components
- Understand inventory structure for multi-region, multi-cluster deployments
- Research role and playbook structure for: ZooKeeper, Kafka brokers, Schema Registry, Kafka Connect
- Understand how Ansible integrates with Azure dynamic inventory (azure.azcollection)
- Research idempotent configuration management for Confluent services (systemd management, config templates)

## Key Questions
- Does cp-ansible support ZooKeeper-based deployments in Platform 7.x?
- How should inventory be structured for 3 regions × 3 brokers per cluster?
- How does Ansible receive VM hostnames/IPs from Terraform outputs?

## Primary References (from README)
- (Ansible docs not explicitly listed in README — using Confluent cp-ansible as primary source)

## Additional References
- https://docs.confluent.io/ansible/current/overview.html
<!-- SECTION:DESCRIPTION:END -->

## Acceptance Criteria
<!-- AC:BEGIN -->
- [x] #1 Confluent Ansible collection (cp-ansible) inventory structure documented
- [x] #2 Playbook patterns for installing and configuring Kafka + ZooKeeper on Ubuntu 22.04 outlined
- [x] #3 Ansible vault usage for Confluent credentials identified
- [x] #4 Idempotency approach for Confluent service management documented
- [x] #5 Variable structure for multi-cluster, multi-region environments designed
- [x] #6 Research doc created in backlog/docs covering: summary, key findings, architecture decisions, configuration reference, risks, and references
<!-- AC:END -->

## Implementation Plan

<!-- SECTION:PLAN:BEGIN -->
### Documentation Output

Publish findings via `backlog-document_create` with title: **Ansible for Confluent Platform Research**

The doc must cover:

- cp-ansible collection capabilities and Platform 7.x coverage
- Inventory structure for 3 regions × 3 brokers per cluster
- Playbook patterns for Kafka + ZooKeeper on Ubuntu 22.04
- Ansible Vault usage for Confluent credentials
- Idempotency approach for Confluent service management (systemd)
- Azure dynamic inventory integration (azure.azcollection)
- Terraform-to-Ansible variable handoff pattern

Follow the standard research doc structure: Summary → Key Findings → Architecture Decisions → Configuration Reference → Risks and Open Questions → References
<!-- SECTION:PLAN:END -->

## Definition of Done
<!-- DOD:BEGIN -->
- [x] #1 Research findings published to backlog/docs via backlog-document_create
<!-- DOD:END -->
