---
id: TASK-1
title: 'SPRINT: Deep Research — Kafka Lab Technical Stack'
status: In Progress
assignee: []
created_date: '2026-03-27 20:43'
labels:
  - sprint
  - research
dependencies: []
priority: high
---

## Description

<!-- SECTION:DESCRIPTION:BEGIN -->
Pre-implementation research sprint covering all technology areas required to design and build the Kafka Lab resilience testing environment.

## Context

The Kafka Lab is a multi-region Azure environment deploying Confluent Platform 7.x (ZooKeeper-based) across three Azure regions (southcentralus primary, mexicocentral secondary, canadaeast DR — 2 active + 1 passive). Three Kafka brokers per cluster, spread across availability zones. Infrastructure provisioned via Terraform AzAPI, configured via Ansible, orchestrated by GitHub Actions. Resilience tested with Azure Chaos Studio. End-to-end visibility provided by two custom Python/FastAPI web apps (producer + consumer).

## Research Areas

1. Confluent Platform 7.x Architecture
2. Confluent Cluster Linking (multi-region)
3. Confluent Schema Registry (multi-DC)
4. Confluent Kafka Connect
5. Confluent Replication and DR
6. Azure VM Infrastructure for Kafka
7. Azure Networking for Kafka
8. Terraform AzAPI Provider
9. Ansible for Confluent Platform
10. GitHub Actions — Terraform + Ansible pipeline
11. Azure Chaos Studio — AZ, region, VM, and Kafka fault scenarios
12. Python FastAPI + Confluent client (producer/consumer apps)
13. Azure Security — UAMI, CMEK, Key Vault

## Decisions Locked In

- Two apps: producer and consumer
- Python / FastAPI app stack
- Confluent Platform 7.x, ZooKeeper-based
- 3 brokers per cluster, spread across AZs
- 2 active clusters (SCUS + MXC) + 1 passive DR (CAE)
- Ubuntu 22.04 LTS on Azure VMs
- Terraform = infra only; Ansible = all app/OS config
- GitHub Actions orchestrates Terraform then Ansible
- Chaos scenarios: AZ failure, region failure, VM-level, Kafka process-level
<!-- SECTION:DESCRIPTION:END -->
