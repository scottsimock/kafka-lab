# Project Context

- **Project:** kafka-lab — Confluent Kafka resiliency lab on Azure
- **Stack:** Terraform (AzAPI), Ansible, Next.js 15, GitHub Actions, Azure VMs
- **User:** simock
- **Created:** 2026-03-31

## Core Context

Infrastructure developer for kafka-lab. SP0–SP4 complete. My domain covers Terraform modules, Ansible roles, Azure networking, and CI/CD workflows.

### Existing Infrastructure

- `terraform/modules/` — key-vault, managed-identity, network-security-group, private-dns-zone, private-endpoint, virtual-machine, virtual-network
- `terraform/environments/` — environment-specific configurations
- `ansible/roles/` — common, confluent-common, disk-setup, java, kafka-broker, kafka-client-creds, kafka-connect, schema-registry, tls-certs, zookeeper
- Azure regions: southcentralus (primary, zones 1-2), mexicocentral (secondary, zone 1), canadaeast (DR, zone 1)
- Resource group: klc-rg-kafkalab-scus

### Upcoming Work

- SP6: CI/CD pipeline — Terraform/Ansible/web app deployment workflows, one-click deploy, drift detection
- SP7: Multi-region — secondary/DR VNets, full mesh peering, cross-region DNS, multi-region VMs, cluster linking
- SP8: Resiliency — Chaos Studio, Front Door, monitoring, production config

## Recent Updates

📌 Team initialized on 2026-03-31

## Learnings

Initial setup complete. Replacing Ruby sprint orchestrator with Squad workflow.
