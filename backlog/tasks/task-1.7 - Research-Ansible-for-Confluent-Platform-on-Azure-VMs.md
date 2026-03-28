---
id: TASK-1.7
title: 'Research: Ansible for Confluent Platform on Azure VMs'
status: To Do
assignee: []
created_date: '2026-03-27 20:44'
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
- [ ] #1 Confluent Ansible collection (cp-ansible) inventory structure documented
- [ ] #2 Playbook patterns for installing and configuring Kafka + ZooKeeper on Ubuntu 22.04 outlined
- [ ] #3 Ansible vault usage for Confluent credentials identified
- [ ] #4 Idempotency approach for Confluent service management documented
- [ ] #5 Variable structure for multi-cluster, multi-region environments designed
<!-- AC:END -->
