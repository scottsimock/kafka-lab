---
id: TASK-29.7
title: SP2.007 — Ansible Java Installation Role
status: To Do
assignee: []
created_date: '2026-03-30 16:42'
updated_date: '2026-03-30 16:43'
labels:
  - story
milestone: m-2
dependencies:
  - TASK-29.5
references:
  - ansible/roles/java/
documentation:
  - doc-8
  - doc-13
parent_task_id: TASK-29
priority: medium
ordinal: 2007
---

## Description

<!-- SECTION:DESCRIPTION:BEGIN -->
Create an Ansible role at ansible/roles/java/ that installs OpenJDK 11 JDK (required by Confluent Platform 7.8.x) on Ubuntu 22.04. Set JAVA_HOME via /etc/environment or profile.d script. Verify the installation with a java -version check. The role should be idempotent.
<!-- SECTION:DESCRIPTION:END -->

## Acceptance Criteria
<!-- AC:BEGIN -->
- [ ] #1 Role exists at ansible/roles/java/ with tasks/, defaults/ directories
- [ ] #2 Installs OpenJDK 11 (Confluent Platform 7.8.x requirement)
- [ ] #3 Sets JAVA_HOME environment variable system-wide
- [ ] #4 Verifies java -version runs successfully
- [ ] #5 Idempotent — skips if already installed at correct version
<!-- AC:END -->
