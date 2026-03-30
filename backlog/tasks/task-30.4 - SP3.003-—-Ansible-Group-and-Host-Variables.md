---
id: TASK-30.4
title: SP3.003 — Ansible Group and Host Variables
status: In Progress
assignee: []
created_date: '2026-03-30 16:44'
updated_date: '2026-03-30 22:25'
labels:
  - story
milestone: m-3
dependencies: []
references:
  - ansible/inventory/group_vars/
  - ansible/inventory/host_vars/
documentation:
  - doc-13
parent_task_id: TASK-30
priority: medium
ordinal: 3003
---

## Description

<!-- SECTION:DESCRIPTION:BEGIN -->
Create Ansible group_vars and host_vars files for ZooKeeper and Kafka broker configuration. group_vars/zookeeper.yml defines ensemble settings. group_vars/kafka_broker.yml defines broker defaults. host_vars/ files define per-host values: broker.id, myid, broker.rack, static IP. Follow the variable hierarchy from doc-13.
<!-- SECTION:DESCRIPTION:END -->

## Acceptance Criteria
<!-- AC:BEGIN -->
- [ ] #1 group_vars/zookeeper.yml defines ZooKeeper-specific variables
- [ ] #2 group_vars/kafka_broker.yml defines broker-specific variables
- [ ] #3 host_vars/ files define per-host broker.id and myid
- [ ] #4 Variables follow Ansible precedence hierarchy from doc-13
- [ ] #5 All variable files use snake_case naming
- [ ] #6 host_vars/ files named to match VM names from azure_rm dynamic inventory (zk-01, zk-02, zk-03, kb-01, kb-02, kb-03)
- [ ] #7 Variable precedence verified: host_vars > group_vars > role defaults per doc-13
- [ ] #8 broker.rack values match Azure Availability Zone assignments
<!-- AC:END -->

## Implementation Plan

<!-- SECTION:PLAN:BEGIN -->
## Implementation Plan

### Step 1: Extend group_vars/zookeeper.yml

Add ZooKeeper role variables to the existing `ansible/group_vars/zookeeper.yml`:

```yaml
# ZooKeeper-specific variables
data_subdirectories:
  - 'zookeeper/data'
  - 'zookeeper/txn-log'

# ZooKeeper ensemble configuration
zookeeper_client_port: 2181
zookeeper_tick_time: 2000
zookeeper_init_limit: 5
zookeeper_sync_limit: 2
zookeeper_heap_size: '1g'
```

These override the role defaults from `roles/zookeeper/defaults/main.yml` at the group level per Ansible variable precedence (group_vars > role defaults). The `data_subdirectories` list is already present; add the ZK-specific variables below it.

### Step 2: Extend group_vars/kafka_broker.yml

Add Kafka broker role variables to the existing `ansible/group_vars/kafka_broker.yml`:

```yaml
# Kafka broker-specific variables
data_subdirectories:
  - 'kafka/data'
  - 'kafka/logs'

# Broker configuration
kafka_broker_heap_size: '6g'
kafka_broker_default_replication_factor: 3
kafka_broker_min_insync_replicas: 2
kafka_broker_num_partitions: 6
kafka_broker_log_retention_hours: 168
```

### Step 3: Create host_vars directory

Create `ansible/host_vars/` directory. The azure_rm dynamic inventory composes `ansible_host` from private IPs. Host var files must be named to match the inventory hostname produced by the azure_rm plugin. The azure_rm plugin uses the VM name as the inventory hostname.

For each ZooKeeper VM, create a host_vars file with the Terraform-assigned VM name:

- `ansible/host_vars/zk-01.yml`:
  ```yaml
  zookeeper_myid: 1
  ```

- `ansible/host_vars/zk-02.yml`:
  ```yaml
  zookeeper_myid: 2
  ```

- `ansible/host_vars/zk-03.yml`:
  ```yaml
  zookeeper_myid: 3
  ```

### Step 4: Create Kafka broker host_vars

For each Kafka broker VM:

- `ansible/host_vars/kb-01.yml`:
  ```yaml
  kafka_broker_id: 1
  kafka_broker_rack: '1'
  ```

- `ansible/host_vars/kb-02.yml`:
  ```yaml
  kafka_broker_id: 2
  kafka_broker_rack: '2'
  ```

- `ansible/host_vars/kb-03.yml`:
  ```yaml
  kafka_broker_id: 3
  kafka_broker_rack: '1'
  ```

The `kafka_broker_rack` values correspond to Azure Availability Zones. Brokers in southcentralus use zones 1 and 2 (zone 1 for kb-01/kb-03, zone 2 for kb-02) per the Azure environment spec.

### Step 5: Validate variable precedence

Verify the Ansible variable precedence hierarchy matches doc-13:
1. **Role defaults** (`roles/*/defaults/main.yml`) — lowest priority, base values
2. **group_vars/all.yml** — shared across all hosts (kafka_user, kafka_group, confluent_version)
3. **group_vars/{component}.yml** — component-specific overrides (heap size, replication factor)
4. **host_vars/{hostname}.yml** — per-host values (broker.id, myid, rack)

This follows standard Ansible precedence: host_vars > group_vars > role defaults.

### Key References
- ZK VM names: zk-01, zk-02, zk-03 (IPs: 10.1.2.4, 10.1.2.5, 10.1.2.6)
- Kafka VM names: kb-01, kb-02, kb-03 (IPs: 10.1.1.4, 10.1.1.5, 10.1.1.6)
- AZ placement: southcentralus zone 1 (kb-01, kb-03), zone 2 (kb-02)
- Existing group_vars: ansible/group_vars/all.yml, zookeeper.yml, kafka_broker.yml
- Variable naming convention: snake_case with component prefix
<!-- SECTION:PLAN:END -->

## Implementation Notes

<!-- SECTION:NOTES:BEGIN -->
## [SM] 2026-03-31T00:00:00Z
- This task is now a dependency for TASK-30.8 (SP3.001 ZK Role) because ZK templates reference `zookeeper_myid` from host_vars. host_vars/ directory does not yet exist in the repo.
- **File contention**: group_vars/kafka_broker.yml is later extended by SP3.005, SP3.007, and SP3.008. Ensure this task creates the base file content that those tasks can safely append to.
<!-- SECTION:NOTES:END -->
