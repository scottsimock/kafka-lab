---
id: TASK-30.9
title: SP3.008 — Kafka Self-Balancing Configuration
status: To Do
assignee: []
created_date: '2026-03-30 16:44'
updated_date: '2026-03-30 22:23'
labels:
  - story
milestone: m-3
dependencies:
  - TASK-30.1
references:
  - ansible/roles/kafka-broker/
documentation:
  - doc-8
parent_task_id: TASK-30
priority: medium
ordinal: 3008
---

## Description

<!-- SECTION:DESCRIPTION:BEGIN -->
Configure Confluent Self-Balancing Clusters on Kafka brokers. Add properties to server.properties: enable balancer, set trigger mode, configure throttle rates for partition movement, and enable the metrics reporter. Per doc-8, self-balancing automatically redistributes partitions when broker topology changes.
<!-- SECTION:DESCRIPTION:END -->

## Acceptance Criteria
<!-- AC:BEGIN -->
- [ ] #1 Self-balancing properties added to server.properties template
- [ ] #2 confluent.balancer.enable=true set
- [ ] #3 confluent.balancer.heal.uneven.load.trigger=ANY_UNEVEN_LOAD
- [ ] #4 Broker throttle rate configured for rebalancing
- [ ] #5 Metrics reporter configured for self-balancing decisions
- [ ] #6 Self-balancing configuration guarded by kafka_broker_self_balancing_enabled boolean
- [ ] #7 confluent.balancer.heal.broker.failure.threshold.ms configured (default 300000)
- [ ] #8 Broker restarts successfully with self-balancing enabled (no errors in broker logs)
<!-- AC:END -->

## Implementation Plan

<!-- SECTION:PLAN:BEGIN -->
## Implementation Plan

### Step 1: Add self-balancing defaults to kafka-broker role

Add to `ansible/roles/kafka-broker/defaults/main.yml`:

```yaml
# Self-Balancing Clusters configuration
kafka_broker_self_balancing_enabled: false
kafka_broker_balancer_trigger: ANY_UNEVEN_LOAD
kafka_broker_balancer_throttle_bytes_per_second: 10485760
kafka_broker_balancer_heal_broker_failure_threshold_ms: 300000
```

### Step 2: Update server.properties.j2 template

Add a conditional self-balancing block to the existing `server.properties.j2` template:

```properties
{% if kafka_broker_self_balancing_enabled | default(false) %}
# Self-Balancing Clusters
confluent.balancer.enable=true
confluent.balancer.heal.uneven.load.trigger={{ kafka_broker_balancer_trigger }}
confluent.balancer.throttle.bytes.per.second={{ kafka_broker_balancer_throttle_bytes_per_second }}
confluent.balancer.heal.broker.failure.threshold.ms={{ kafka_broker_balancer_heal_broker_failure_threshold_ms }}
{% endif %}
```

Place this block at the end of the server.properties.j2 template, after tiered storage (if present).

### Step 3: Enable in group_vars/kafka_broker.yml

Add to `ansible/group_vars/kafka_broker.yml`:

```yaml
kafka_broker_self_balancing_enabled: true
```

### Step 4: Document trigger modes

Per doc-8, two trigger modes exist:
- `EMPTY_BROKER` — rebalance only when a broker is added/removed (low overhead, for dev)
- `ANY_UNEVEN_LOAD` — continuous balancing for detected imbalances (recommended for production)

The default `ANY_UNEVEN_LOAD` is appropriate for kafka-lab production topology.

### Step 5: Configure throttle appropriately

Per doc-8:
- Dev environment: 10 MB/s (`10485760` bytes/s) — default in our config
- Production: 50-100 MB/s (`52428800`–`104857600` bytes/s)

The default of 10 MB/s is suitable for the kafka-lab dev cluster.

### Step 6: Verify no conflict with Auto Data Balancer

Per doc-8, Self-Balancing and Auto Data Balancer (ADB) cannot coexist. Ensure no `confluent.rebalancer.enable=true` or similar ADB properties are present in the template.

### Step 7: Internal topic replication

SBC creates internal topics (`_confluent_balancer_*`). These use `default.replication.factor` from the broker config (already set to 3 in SP3.002). No additional configuration needed.

### Key References
- doc-8: Self-Balancing Cluster section
- Trigger: ANY_UNEVEN_LOAD (production recommended)
- Throttle: 10 MB/s for dev, 50-100 MB/s for production
- Failure threshold: 300000 ms (5 minutes)
- Internal topics use default.replication.factor=3
- Mutual exclusion: cannot run with Auto Data Balancer
<!-- SECTION:PLAN:END -->

## Implementation Notes

<!-- SECTION:NOTES:BEGIN -->
## [SM] 2026-03-31T00:00:00Z
- Added missing AC for broker restart verification (SP3.007 has equivalent AC #6 for tiered storage, this task lacked it).
- **File contention**: server.properties.j2 is also modified by SP3.005 and SP3.007. group_vars/kafka_broker.yml is modified by SP3.003, SP3.005, and SP3.007. TL must serialize SP3.005 → SP3.007 → SP3.008 for template edits, or ensure non-overlapping regions.
<!-- SECTION:NOTES:END -->
