---
id: TASK-29.8
title: SP2.008 — Ansible Confluent Platform Installation Role
status: To Do
assignee: []
created_date: '2026-03-30 16:42'
updated_date: '2026-03-30 16:43'
labels:
  - story
milestone: m-2
dependencies:
  - TASK-29.7
references:
  - ansible/roles/confluent-common/
documentation:
  - doc-8
  - doc-13
parent_task_id: TASK-29
priority: high
ordinal: 2008
---

## Description

<!-- SECTION:DESCRIPTION:BEGIN -->
Create an Ansible role at ansible/roles/confluent-common/ that downloads and installs the Confluent Platform 7.8.0 archive. Download from packages.confluent.io, extract to /opt/confluent, create a current symlink, add bin to PATH. This role is a dependency for all component-specific roles (zookeeper, kafka-broker, etc.).
<!-- SECTION:DESCRIPTION:END -->

## Acceptance Criteria
<!-- AC:BEGIN -->
- [ ] #1 Role exists at ansible/roles/confluent-common/ with tasks/, defaults/, vars/, templates/ directories
- [ ] #2 Downloads and extracts Confluent Platform 7.8.0 archive to /opt/confluent
- [ ] #3 Creates symlink /opt/confluent/current -> /opt/confluent/confluent-7.8.0
- [ ] #4 Adds Confluent bin directory to system PATH
- [ ] #5 Sets confluent_version as a configurable default (7.8.0)
- [ ] #6 Verifies kafka-topics --version runs successfully
<!-- AC:END -->
