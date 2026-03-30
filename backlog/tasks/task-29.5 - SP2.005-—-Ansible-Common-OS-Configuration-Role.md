---
id: TASK-29.5
title: SP2.005 — Ansible Common OS Configuration Role
status: To Do
assignee: []
created_date: '2026-03-30 16:42'
updated_date: '2026-03-30 16:43'
labels:
  - story
milestone: m-2
dependencies:
  - TASK-29.4
references:
  - ansible/roles/common/
documentation:
  - doc-13
  - doc-12
parent_task_id: TASK-29
priority: high
ordinal: 2005
---

## Description

<!-- SECTION:DESCRIPTION:BEGIN -->
Create a common Ansible role at ansible/roles/common/ that handles base OS configuration shared by all Kafka component VMs. The role installs essential packages, creates the kafka system user/group, sets sysctl parameters (vm.swappiness=1, vm.max_map_count=262144, net.core.wmem_max/rmem_max), configures ulimits for the kafka user, and performs basic OS hardening. Use FQCN for all modules.
<!-- SECTION:DESCRIPTION:END -->

## Acceptance Criteria
<!-- AC:BEGIN -->
- [ ] #1 Role exists at ansible/roles/common/ with tasks/, handlers/, defaults/, templates/, files/ directories
- [ ] #2 tasks/main.yml imports install.yml and configure.yml
- [ ] #3 Configures timezone, locale, and hostname
- [ ] #4 Installs base packages: ca-certificates, curl, gnupg, lsb-release, jq, unzip, net-tools
- [ ] #5 Configures sysctl settings for Kafka (vm.swappiness=1, vm.max_map_count=262144, net.core.wmem/rmem)
- [ ] #6 Configures ulimits for kafka user (nofile 100000, nproc 32768)
- [ ] #7 Creates kafka system user and group
<!-- AC:END -->
