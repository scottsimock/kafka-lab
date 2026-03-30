---
id: TASK-30.1
title: SP3.002 — Ansible Kafka Broker Role
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
  - ansible/roles/kafka-broker/
documentation:
  - doc-8
  - doc-13
parent_task_id: TASK-30
priority: high
ordinal: 3002
---

## Description

<!-- SECTION:DESCRIPTION:BEGIN -->
Create the Kafka broker Ansible role at ansible/roles/kafka-broker/ that configures and deploys Kafka brokers. The role renders server.properties from a Jinja2 template with broker.id, listeners, advertised.listeners, log.dirs, replication settings, and ZooKeeper connection. Configure JVM settings per doc-8: 6 GB heap for D4s_v5, G1GC. Create systemd unit and health check handler. Dev config: PLAINTEXT listeners (TLS added in SP3.005).
<!-- SECTION:DESCRIPTION:END -->

## Acceptance Criteria
<!-- AC:BEGIN -->
- [ ] #1 Role exists at ansible/roles/kafka-broker/ with tasks/, handlers/, defaults/, templates/ directories
- [ ] #2 Renders server.properties from Jinja2 template with configurable broker.id, listeners, log.dirs
- [ ] #3 Configures broker.rack from availability zone
- [ ] #4 Sets replication factor defaults: default.replication.factor=3, min.insync.replicas=2
- [ ] #5 Configures JVM heap settings (KAFKA_HEAP_OPTS=-Xmx6g -Xms6g for D4s_v5)
- [ ] #6 Creates Kafka log directory at /data/kafka/logs
- [ ] #7 Creates systemd unit file confluent-kafka.service
- [ ] #8 Handler restarts and verifies broker registration
<!-- AC:END -->
