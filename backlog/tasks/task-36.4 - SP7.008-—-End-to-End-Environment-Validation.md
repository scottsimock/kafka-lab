---
id: TASK-36.4
title: SP7.008 — End-to-End Environment Validation
status: Dev Complete
assignee:
  - Sid
created_date: '2026-03-31 22:01'
updated_date: '2026-03-31 22:36'
labels:
  - story
milestone: m-9
dependencies:
  - TASK-36.1
references:
  - terraform/environments/
  - ansible/
parent_task_id: TASK-36
priority: high
ordinal: 6508
---

## Description

<!-- SECTION:DESCRIPTION:BEGIN -->
Create a comprehensive E2E validation suite that checks the full dev environment stack: VM health (all VMs reachable), Kafka cluster health (brokers in ISR, ZooKeeper quorum), Schema Registry health, Kafka Connect health, Function App health, web app accessibility, inter-component connectivity (web app can reach Kafka through Function App). Produces a structured health report.
<!-- SECTION:DESCRIPTION:END -->

## Acceptance Criteria
<!-- AC:BEGIN -->
- [x] #1 Health check: all VMs reachable and reporting healthy
- [x] #2 Health check: Kafka cluster has all brokers in ISR with elected controller
- [x] #3 Health check: ZooKeeper ensemble has quorum
- [x] #4 Health check: Schema Registry responding on expected port
- [x] #5 Health check: Kafka Connect worker responding on expected port
- [x] #6 Health check: Function App returns healthy from health endpoint
- [x] #7 Health check: web app pages load through the full stack
- [x] #8 Health check: data flow validation (produce then consume round-trip)
- [x] #9 Structured health report generated with pass/fail per component
<!-- AC:END -->

## Implementation Notes

<!-- SECTION:NOTES:BEGIN -->
## [Sid] 2026-04-01
- Created `scripts/validate-dev-environment.sh` — comprehensive bash E2E validation (8 phases, 25+ checks)
- Created `ansible/playbooks/validate-e2e.yml` — Ansible alternative with identical coverage
- Updated `docs/deploy-dev.md` with full Validation section (usage, phases, report format, interpretation)
- Both tools output structured JSON to `logs/dev-environment-health.json`
- Bash script supports `--from-terraform`, `--skip-data-flow`, `--skip-webapp`, env var overrides
- Ansible playbook supports extra vars: `skip_data_flow`, `skip_webapp`, `function_app_host`
- Both validate syntax (bash -n, yaml.safe_load) — clean
<!-- SECTION:NOTES:END -->
