---
id: doc-4
title: Project Decisions — Grill Session 1
type: other
created_date: '2026-03-29 17:52'
---
# Project Decisions — Grill Session 1

Resolved during the initial project harness grilling session.

## Task & Backlog Conventions

| # | Decision | Resolution |
|---|---|---|
| 1 | **Task ID format** | `task-{type}-SP{#}.{###}-{description}` (e.g., `task-research-SP0.001-kafka-overview`) |
| 2 | **Task types** | `sprint`, `story`, `research`, `doc`, `test`, `bug` |
| 3 | **Sprint grouping** | Milestones (`SP0`, `SP1`, etc.) + parent sprint tasks for directives |
| 4 | **Research task time limit** | 5–8 minutes (relaxed from the 2-min implementation limit) |
| 5 | **Implementation task time limit** | 2 minutes per coder cycle |
| 6 | **Sprint duration cap** | 25 minutes |
| 10 | **Research docs** | Use Backlog MCP `document_create` with descriptive titles |
| 19 | **Backlog statuses** | `To Do`, `In Progress`, `Dev Complete`, `In Review`, `Done` |

## Agent Execution Model

| # | Decision | Resolution |
|---|---|---|
| 5 | **Agent role definitions** | Define roles/responsibilities in `.agent.md` files; fg/bg controlled at invocation |
| 6 | **Parallelism** | No hard cap; TL manages dynamically, avoids assigning overlapping file dependencies |
| 7 | **Tester scoring rubric** | Weighted: AC met (30%), Test coverage (25%), Docs (15%), Code quality (15%), Edge cases (15%). Pass threshold ≥90%, SP0 target ≥95% |

## Git & Sprint Workflow

| # | Decision | Resolution |
|---|---|---|
| 8 | **SP0 branching** | Single branch `sprint/SP0` for both P1 and P2, single PR at end |
| 9 | **Branch naming** | `sprint/SP{#}` (e.g., `sprint/SP0`, `sprint/SP1`) |
| 18 | **Commit discipline** | Coder commits per task, task ID in commit message |
| 20 | **Sprint completion** | All tasks Done + PR created + summary printed → Ruby hard stops, waits for human |

## Infrastructure & Architecture

| # | Decision | Resolution |
|---|---|---|
| 11 | **Environment progression** | Separate `.tfvars` per environment (dev/staging/prod) |
| 12 | **Web app stack** | Next.js 15 + TypeScript |
| 13 | **Web app hosting** | Azure Function Apps with VNet integration |
| 14 | **Kafka client** | `confluent-kafka-javascript` in Next.js API routes |
| 15 | **Confluent Platform version** | Pinned to 7.8.x |
| 16 | **One-click deployment** | Single `workflow_dispatch` GitHub Actions workflow with staged jobs (Terraform → Ansible → App) |
| 17 | **Chaos Studio timing** | Late sprints (SP3/SP4+) after multi-region is working |
| 22 | **Dev VM sizing** | Brokers: D4s_v5 (3), ZK: D2s_v5 (3), SR: D2s_v5 (1), Connect: D2s_v5 (1). Refine during research |
| 23 | **Consensus** | ZooKeeper (as specified in requirements) |
| 24 | **Ansible structure** | One role per Confluent component, dynamic Azure inventory |
| 25 | **Tiered storage** | Azure Blob Storage with private endpoint + CMEK |
| 26 | **Monitoring** | JMX → Prometheus → Grafana |

## Web App UX

| # | Decision | Resolution |
|---|---|---|
| 27 | **UI scope** | Focused 4-view dashboard: Cluster Overview, Topic Manager, Message Explorer, Health Monitor |
| 28 | **Schema Registry** | Deployed as infrastructure; schema enforcement optional in web app |

## Deferred to Research (SP0)

| Topic | Reason |
|---|---|
| Kafka auth model (SASL/SCRAM, mTLS, RBAC) | Complex decision requiring research |
| Cluster linking topology | Multi-region topology needs research |
| Any further architectural decisions | Research phase will resolve |
