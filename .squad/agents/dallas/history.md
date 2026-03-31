# Project Context

- **Project:** kafka-lab — Confluent Kafka resiliency lab on Azure
- **Stack:** Terraform (AzAPI), Ansible, Next.js 15, GitHub Actions, Azure VMs
- **User:** simock
- **Created:** 2026-03-31

## Core Context

Frontend and full-stack developer for kafka-lab. SP0–SP4 complete (infrastructure and Kafka platform). My domain is the web application and Azure Functions.

### Upcoming Work (SP5)

- Next.js 15 project scaffolding with App Router
- Shared Kafka client module (confluent-kafka)
- Kafka API route handlers (topics, partitions, brokers, consumer groups)
- Message produce and consume API routes
- Dashboard views: cluster overview, topic detail, consumer groups, message browser
- Schema browser view and API routes
- Azure Function App infrastructure (Terraform + Python functions)

### Architecture Notes

- Web app runs in same regions and AZs as Kafka clusters
- All connections via private endpoints — no public access
- southcentralus (primary), mexicocentral (secondary), canadaeast (DR)
- Must be easy to use — one-click topic creation, message reading from any topic

## Recent Updates

📌 Team initialized on 2026-03-31

## Learnings

Initial setup complete. Replacing Ruby sprint orchestrator with Squad workflow.
