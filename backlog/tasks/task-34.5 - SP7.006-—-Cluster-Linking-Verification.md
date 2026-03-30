---
id: TASK-34.5
title: SP7.006 — Cluster Linking Verification
status: To Do
assignee: []
created_date: '2026-03-30 16:50'
updated_date: '2026-03-30 16:50'
labels:
  - story
milestone: m-7
dependencies:
  - TASK-34.8
references:
  - ansible/playbooks/
documentation:
  - doc-9
parent_task_id: TASK-34
priority: high
ordinal: 7006
---

## Description

<!-- SECTION:DESCRIPTION:BEGIN -->
Verify Cluster Linking is operational: check mirror topics appear on destination clusters, consumer offsets are synced, replication lag is within acceptable bounds. Test mirror topic promotion (pause, promote to writable) on a test topic. Create monitoring scripts for ongoing link health. Per doc-9.
<!-- SECTION:DESCRIPTION:END -->

## Acceptance Criteria
<!-- AC:BEGIN -->
- [ ] #1 Mirror topics appear on destination clusters with correct prefix
- [ ] #2 Consumer offsets synced across regions within 30s
- [ ] #3 Mirror topic lag monitoring shows acceptable lag
- [ ] #4 Mirror topic promotion tested (can promote to writable)
- [ ] #5 Cluster link describe shows healthy status for all links
<!-- AC:END -->
