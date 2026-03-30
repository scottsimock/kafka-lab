---
id: TASK-30.8
title: SP3.001 — Ansible ZooKeeper Role
status: To Do
assignee: []
created_date: '2026-03-30 16:44'
updated_date: '2026-03-30 16:44'
labels:
  - story
milestone: m-3
dependencies:
  - TASK-29.8
references:
  - ansible/roles/zookeeper/
documentation:
  - doc-8
  - doc-13
parent_task_id: TASK-30
priority: high
ordinal: 3001
---

## Description

<!-- SECTION:DESCRIPTION:BEGIN -->
Create the ZooKeeper Ansible role at ansible/roles/zookeeper/ that configures and deploys a 3-node ZooKeeper ensemble. The role renders zookeeper.properties from a Jinja2 template, creates the myid file, configures ensemble membership, creates a systemd unit, and includes health check handlers. Configuration per doc-8: clientPort 2181, tickTime 2000, initLimit 5, syncLimit 2, autopurge enabled.
<!-- SECTION:DESCRIPTION:END -->

## Acceptance Criteria
<!-- AC:BEGIN -->
- [ ] #1 Role exists at ansible/roles/zookeeper/ with tasks/, handlers/, defaults/, templates/ directories
- [ ] #2 Renders zookeeper.properties from Jinja2 template with configurable tickTime, initLimit, syncLimit
- [ ] #3 Creates myid file with unique server ID for each node
- [ ] #4 Creates data and txn log directories at /data/zookeeper/data and /data/zookeeper/log
- [ ] #5 Configures ensemble membership (server.1, server.2, server.3) with correct IPs
- [ ] #6 Creates systemd unit file confluent-zookeeper.service
- [ ] #7 Handler restarts and verifies ZK health via ruok four-letter command
<!-- AC:END -->
