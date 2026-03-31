# Project Context

- **Project:** kafka-lab — Confluent Kafka resiliency lab on Azure
- **Stack:** Terraform (AzAPI), Ansible, Next.js 15, GitHub Actions, Azure VMs
- **User:** simock
- **Created:** 2026-03-31

## Core Context

Tester for kafka-lab. SP0–SP4 complete. My domain is validation, quality gates, and edge case analysis across all layers.

### What's Been Built

- 7 Terraform modules (VNet, KV, UAMI, NSG, DNS, Private Endpoint, VM)
- 10 Ansible roles (common, confluent-common, disk-setup, java, zookeeper, kafka-broker, tls-certs, kafka-client-creds, schema-registry, kafka-connect)
- Full Kafka platform: TLS, SASL/SCRAM, tiered storage, self-balancing, ACLs
- Ecosystem: Schema Registry, Kafka Connect, Blob sink connector

### Upcoming Testing Areas

- SP5: Next.js API routes, Kafka client module, dashboard views, Azure Functions
- SP6: CI/CD workflow validation, deployment pipeline testing
- SP7: Cross-region connectivity, VNet peering, cluster linking verification
- SP8: Chaos experiments, failover behavior, SLO validation

## Recent Updates

📌 Team initialized on 2026-03-31

## Learnings

Initial setup complete. Replacing Ruby sprint orchestrator with Squad workflow.

## Sprint Update: SP7 Injection (2026-03-31T17:56-04:00)

**By:** Zorg (Sprint Orchestrator)

The sprint roadmap was restructured. A new SP7 (Dev Environment Deployment & Integration Testing) was injected between CI/CD (SP6) and multi-region expansion. Former SP7 (Multi-Region) renamed to SP8. Former SP8 (Resiliency) renamed to SP9.

**New Sprints:**
- SP7: Dev Environment Deployment & Integration Testing (10 stories)
- SP8: Multi-Region Expansion (was SP7)
- SP9: Resiliency and Production Hardening (was SP8)

**Rationale:** Validate single-region dev environment before multi-region complexity. Aligns with REQUIREMENTS.md strategy.

**Impact on Sid:** Upcoming QA work (resiliency hardening) is now SP9. No scope changes — only sprint numbers shifted. Ready to start after multi-region validation (SP8) is complete.
