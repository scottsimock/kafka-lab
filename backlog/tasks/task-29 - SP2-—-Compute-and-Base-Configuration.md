---
id: TASK-29
title: SP2 — Compute and Base Configuration
status: To Do
assignee: []
created_date: '2026-03-30 16:40'
updated_date: '2026-03-30 17:09'
labels:
  - sprint
milestone: m-2
dependencies: []
priority: high
ordinal: 2000
---

## Description

<!-- SECTION:DESCRIPTION:BEGIN -->
Compute and base configuration sprint covering VM provisioning for ZooKeeper and Kafka broker nodes, Ansible project structure, base OS configuration roles, disk setup, and Confluent Platform package installation. All VMs deployed in southcentralus Zone 1 for the dev environment.
<!-- SECTION:DESCRIPTION:END -->

## Acceptance Criteria
<!-- AC:BEGIN -->
- [ ] #1 VM Terraform module provisions ZooKeeper, Kafka broker, Schema Registry, and Kafka Connect instances in southcentralus Zone 1
- [ ] #2 Ansible project structure includes dynamic inventory, site playbook, and role-based organization
- [ ] #3 Common OS configuration role applies base hardening and prerequisites to all VMs
- [ ] #4 Data disk setup role mounts and formats dedicated disks for Kafka and ZooKeeper data
- [ ] #5 Confluent Platform packages are installed on all target VMs via Ansible role
<!-- AC:END -->
