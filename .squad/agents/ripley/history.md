# Project Context

- **Project:** kafka-lab — Confluent Kafka resiliency lab on Azure
- **Stack:** Terraform (AzAPI), Ansible, Next.js 15, GitHub Actions, Azure VMs
- **User:** simock
- **Created:** 2026-03-31

## Core Context

Lead agent for kafka-lab. SP0–SP4 complete (foundation infra, compute, Kafka platform, ecosystem services). Remaining: SP5 (Web App), SP6 (CI/CD), SP7 (Multi-Region), SP8 (Resiliency).

### Codebase Structure

- `terraform/modules/` — key-vault, managed-identity, network-security-group, private-dns-zone, private-endpoint, virtual-machine, virtual-network
- `terraform/environments/` — environment-specific configs
- `ansible/roles/` — common, confluent-common, disk-setup, java, kafka-broker, kafka-client-creds, kafka-connect, schema-registry, tls-certs, zookeeper
- `ansible/playbooks/` — deployment and verification playbooks
- `backlog/` — sprint tasks and milestones (SP0–SP8)
- Azure regions: southcentralus (primary), mexicocentral (secondary), canadaeast (DR)

### Previous Sprint History

- SP1: Foundation infrastructure — VNet, KV, UAMI, DNS, NSG, Storage, Private Endpoints (PR #2)
- SP2: Compute — VM module, ZK/Broker/SR/Connect VMs, Ansible roles for OS/disk/Java/Confluent (PR #3)
- SP3: Kafka platform — ZK role, Broker role, TLS, SASL/SCRAM, tiered storage, self-balancing, ACLs (PR #4)
- SP4: Ecosystem — Schema Registry role, Kafka Connect role, Blob sink connector, topic creation, schema registration (PR #5)

## Recent Updates

📌 Team initialized on 2026-03-31

## Learnings

Initial setup complete. Replacing Ruby sprint orchestrator with Squad workflow.
