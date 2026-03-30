---
id: TASK-29.6
title: SP2.006 — Ansible Data Disk Setup Role
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
  - ansible/roles/disk-setup/
documentation:
  - doc-12
  - doc-13
parent_task_id: TASK-29
priority: medium
ordinal: 2006
---

## Description

<!-- SECTION:DESCRIPTION:BEGIN -->
Create an Ansible role at ansible/roles/disk-setup/ that handles data disk detection, formatting (XFS), mounting, and fstab persistence. The role detects the attached data disk, formats with XFS if not already formatted, mounts at a configurable path (default /data) with noatime,nodiratime options, creates an fstab entry, and sets ownership to the kafka user. Accept variables for mount_path and subdirectories to create.
<!-- SECTION:DESCRIPTION:END -->

## Acceptance Criteria
<!-- AC:BEGIN -->
- [ ] #1 Role exists at ansible/roles/disk-setup/ with tasks/, defaults/ directories
- [ ] #2 Detects and formats data disk with XFS filesystem
- [ ] #3 Mounts data disk with noatime,nodiratime options
- [ ] #4 Adds fstab entry for persistence
- [ ] #5 Sets ownership to kafka user/group
- [ ] #6 Creates component-specific subdirectories based on variable input
- [ ] #7 Idempotent — skips formatting if filesystem already exists
<!-- AC:END -->
