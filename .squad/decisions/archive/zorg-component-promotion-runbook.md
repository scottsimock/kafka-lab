# Confluent Platform Component Promotion Runbook

> **Author:** Zorg (Lead) | **Date:** 2026-04-02 | **Status:** Draft

## Purpose

This document provides the concrete operational steps for promoting Confluent Platform components during AZ or region failover. It builds on the risk analysis in doc-19 by answering: **what exactly do we do when an AZ or region goes down?**

This runbook covers:

1. State inventory for each component (ZooKeeper, Kafka brokers, Schema Registry, Kafka Connect)
2. Failure impact (intra-AZ vs cross-region)
3. Concrete promotion steps with commands
4. Component dependency ordering
5. ZooKeeper-specific concerns (quorum, leader election)

---

## Architecture Context

**Current deployment (dev):**

- **Region:** southcentralus (primary), zones 1-2
- **ZooKeeper ensemble:** 3 nodes (zk-01, zk-02, zk-03) at 10.1.2.4-6
- **Kafka brokers:** 3 nodes (kb-01, kb-02, kb-03) at 10.1.1.4-6
- **Schema Registry:** 1 node (sr-01) at 10.1.3.4
- **Kafka Connect:** 1 node (kc-01) at 10.1.4.4
- **Replication:** `default.replication.factor=1`, `min.insync.replicas=1` (dev mode)
- **Security:** `kafka_broker_security_enabled: false` (dev mode)

**Future state (production, SP8+):**

- **Regions:** southcentralus (primary), mexicocentral (secondary), canadacentral (DR)
- **Cluster linking:** Active for multi-region replication
- **Replication:** `default.replication.factor=3`, `min.insync.replicas=2`
- **Security:** SASL_SSL with SCRAM-SHA-512

---

## Part 1: State Inventory

### 1.1 ZooKeeper State

**What ZooKeeper holds:**

- **Broker metadata:** Broker IDs, endpoints, rack awareness, controller election state
- **Topic metadata:** Partition assignment, ISR (in-sync replica) lists per partition
- **Consumer group metadata:** Group coordinator assignment, rebalance state (note: offsets stored in `__consumer_offsets` topic, not ZK as of Kafka 2.0+)
- **ACLs:** If `kafka_broker_acl_enabled: true` (not currently enabled in dev)
- **Quotas:** Client quota configs
- **Configuration:** Dynamic broker/topic configs set via `kafka-configs.sh`
- **Controller state:** Which broker is the controller (manages partition leader election, ISR changes)

**Persistence:**

- **Data directory:** `{{ data_mount_path }}/zookeeper/data` (persistent Azure disk)
- **Transaction log:** `{{ data_mount_path }}/zookeeper/txn-log` (persistent Azure disk)
- **Ensemble config:** `zookeeper.properties` lists all ZK nodes with `server.{myid}={host}:{leader_port}:{election_port}`

**ZooKeeper quorum math:**

- Quorum = `floor(N / 2) + 1` where N = total nodes
- 3-node ensemble: quorum = 2 (can tolerate 1 failure)
- 5-node ensemble: quorum = 3 (can tolerate 2 failures)

**Leader election:**

- ZooKeeper uses Zab (ZooKeeper Atomic Broadcast) protocol
- When leader dies, ensemble elects new leader via voting (requires quorum)
- Election takes 200ms – 2s typically
- During election, cluster is **read-only** — no metadata updates, but brokers continue serving existing partition traffic

### 1.2 Kafka Broker State

**What Kafka brokers hold:**

- **Partition replicas:** Log segments on disk in `{{ data_mount_path }}/kafka/logs`
- **ISR membership:** Each replica knows if it's in-sync (tracks via ZK + local state)
- **Controller role:** One broker is elected controller (via ZK ephemeral node `/controller`)
- **Producer state:** Idempotent producer PIDs, epochs, sequence numbers (per partition, in `__producer_state` snapshot files)
- **Transaction state:** Transaction coordinator state in `__transaction_state` topic
- **Consumer group coordinator state:** Group metadata in `__consumer_offsets` topic
- **Tiered storage pointers:** If `kafka_broker_tiered_storage_enabled: true`, brokers track which segments uploaded to Azure Blob

**Persistence:**

- **Log segments:** On Azure persistent disks, survive broker restart
- **Metadata:** In ZooKeeper (ephemeral nodes for liveness, persistent nodes for metadata)

**Controller responsibilities:**

- Partition leader election when broker fails
- ISR shrinking when replica falls behind
- Broker registration/deregistration
- Topic creation/deletion
- Dynamic config changes

**Broker failure impact:**

- If controller broker dies → new controller elected via ZK (takes 1-5s)
- If non-controller broker dies → controller updates ISR for partitions on dead broker, elects new leaders from remaining ISR members
- If `min.insync.replicas` not met → partition becomes unavailable for writes (producers get `NOT_ENOUGH_REPLICAS` error)

### 1.3 Schema Registry State

**What Schema Registry holds:**

- **Schemas:** Stored in `_schemas` Kafka topic (compacted, replication factor 3 in prod)
- **Schema IDs:** Monotonically increasing IDs assigned by leader SR
- **Compatibility cache:** In-memory cache of compatibility checks (ephemeral)
- **Leader/follower state:** Schema Registry uses Kafka group protocol to elect a leader among SR instances

**Leader election:**

- All Schema Registry instances are consumers of `_schemas` topic
- Leader is the instance that "owns" the single partition of `_schemas` (for writes)
- Followers are read-only replicas (can serve GET requests but reject POST/PUT)
- Election happens via Kafka consumer group rebalance (takes 1-10s)

**Persistence:**

- **`_schemas` topic:** Source of truth, fully durable on Kafka
- **Local cache:** Ephemeral, rebuilt on SR restart by consuming `_schemas` from beginning

**Failure impact:**

- If leader SR dies → follower becomes leader after rebalance (1-10s)
- During rebalance, **no schema registration** possible (POST/PUT to `/subjects/.../versions` returns 500)
- Schema reads (GET) still work if hitting a follower

### 1.4 Kafka Connect State

**What Kafka Connect holds:**

- **Connector configs:** In `connect-configs` topic (compacted, replication factor 3 in prod)
- **Task offsets:** In `connect-offsets` topic (per-connector source offsets or sink progress, replication factor 3)
- **Task status:** In `connect-status` topic (compacted, replication factor 3 in prod)
- **Distributed mode state:** Workers coordinate via Kafka consumer group protocol (group ID = `connect-cluster`)

**Leader election:**

- Workers use Kafka group protocol to elect a leader
- Leader assigns connectors and tasks to workers
- Rebalance happens when worker joins/leaves (takes 5-30s depending on `session.timeout.ms`)

**Persistence:**

- **All state in Kafka topics:** `connect-configs`, `connect-offsets`, `connect-status`
- **No local state** (distributed mode is stateless except for in-flight connector instances)

**Failure impact:**

- If worker dies → remaining workers rebalance, leader reassigns tasks (5-30s)
- Connectors may restart from last committed offset (exact location depends on connector implementation)
- If all workers die → restart workers, they consume topics from beginning, reconstruct state, resume

---

## Part 2: Failure Scenarios

### 2.1 Intra-Region AZ Failure (e.g., southcentralus Zone 1 → Zone 2)

**Assumption:** VMs in Zone 1 become unavailable. Zone 2 VMs are healthy.

#### 2.1.1 ZooKeeper Ensemble Impact

**Scenario:** 3-node ensemble, 2 nodes in Zone 1, 1 node in Zone 2

- **Quorum loss:** Only 1/3 nodes remain → no quorum (need 2/3) → **ZooKeeper unavailable**
- **Impact:** Kafka cluster **cannot elect new partition leaders, cannot register new brokers, cannot update metadata**
- **Existing traffic:** Brokers continue serving existing partitions with cached metadata for ~minutes, but any partition leader on dead brokers becomes unavailable
- **Mitigation:** Deploy ZK nodes across 3 AZs (or 2 AZs + 1 cross-region) to maintain quorum

**Scenario:** 3-node ensemble, 1 node per AZ (Zone 1, Zone 2, Zone 3)

- **Quorum retained:** 2/3 nodes remain → quorum maintained → leader re-election happens (200ms – 2s)
- **Impact:** Brief read-only window during election, then normal operation resumes
- **Kafka impact:** Controller may relocate if it was on Zone 1 broker

**Action required:** None if quorum retained. If quorum lost, **this is a cluster-wide outage** — cannot promote anything until ZK quorum is restored (requires bringing up a third ZK node manually or via disaster recovery playbook).

#### 2.1.2 Kafka Broker Impact

**Scenario:** 3 brokers, replication factor 3, min.insync.replicas 2, 1 broker in each AZ

- **Zone 1 broker dies**
- **Controller:** If controller was on Zone 1 broker → new controller elected via ZK (1-5s)
- **Partitions with leader on dead broker:** Controller elects new leaders from ISR (typically <1s per partition, happens in parallel)
- **ISR shrinking:** Dead broker removed from ISR for all partitions
- **Producer impact:** Brief unavailability (retries kick in) while leader election happens
- **Consumer impact:** Metadata refresh picks up new leaders (transparent if `enable.auto.commit=true`)

**Replication factor implications:**

- RF=3, min.insync.replicas=2: After 1 broker dies, 2 replicas remain → can still write (but no fault tolerance left — 2/2 must be in-sync)
- RF=3, min.insync.replicas=3: After 1 broker dies, **partitions become unavailable for writes** (producers get `NOT_ENOUGH_REPLICAS_AFTER_APPEND`)

**Action required:**

1. **Monitor ISR:** Check that partitions have sufficient in-sync replicas: `kafka-topics.sh --describe --under-replicated-partitions`
2. **No manual promotion needed** — Kafka controller handles this automatically
3. **Add replacement broker:** Bring up a new broker in Zone 2 or Zone 3, reassign partitions to restore replication factor
4. **Producer config adjustment (optional):** If `min.insync.replicas=3`, consider lowering to 2 during degraded state to allow writes (trade-off: reduced durability)

#### 2.1.3 Schema Registry Impact

**Scenario:** 1 SR instance in Zone 1, dies

- **If leader:** Kafka consumer rebalance elects new leader (but there's no other instance in this scenario → **SR unavailable**)
- **Mitigation:** Run 2+ SR instances across AZs

**Scenario:** 3 SR instances, 1 per AZ, leader in Zone 1 dies

- **Rebalance:** One of the remaining SRs in Zone 2/3 becomes leader (1-10s)
- **Schema reads:** Continue on remaining instances
- **Schema writes:** Fail during rebalance (500 error), resume once new leader elected

**Action required:** None — automatic. Producers may need to retry schema registration once (client libraries handle this).

#### 2.1.4 Kafka Connect Impact

**Scenario:** 1 Connect worker in Zone 1, dies

- **If only worker:** All connectors stop until worker restarts
- **Mitigation:** Run 2+ Connect workers across AZs

**Scenario:** 3 Connect workers, 1 per AZ, one worker in Zone 1 dies

- **Rebalance:** Remaining workers rebalance tasks (5-30s)
- **Connector downtime:** Brief interruption while tasks reassign
- **Offset commit:** Workers commit offsets periodically (default `offset.flush.interval.ms=60000`), so up to 60s of reprocessing possible

**Action required:** None — automatic. Monitor connector status via REST API: `GET http://kc-01:8083/connectors/{name}/status`

### 2.2 Cross-Region Failover (e.g., southcentralus → mexicocentral)

**Assumption:** Entire southcentralus region unavailable. Cluster linking active. Mirror topics exist in mexicocentral.

This is a **manual, orchestrated failover** because Kafka does not automatically fail over to a different cluster.

#### 2.2.1 ZooKeeper Ensemble Impact

**Scenario:** ZK ensemble entirely in southcentralus → **total loss**

**Impact:** Cannot manage Kafka metadata for old cluster (irrelevant if entire cluster is dead)

**Action for failover cluster:**

- **mexicocentral has its own ZK ensemble** (3 nodes, independent)
- No cross-region ZK coordination (by design — we run independent clusters)
- No promotion needed — mexicocentral ZK continues operating independently

#### 2.2.2 Kafka Broker Impact

**Scenario:** All brokers in southcentralus dead. Mirror topics exist in mexicocentral via cluster linking.

**State:**

- **Mirror topics are read-only** in mexicocentral by default
- **Producer PID/epoch reset** — producers get new PIDs from mexicocentral cluster (idempotency window breaks, see doc-19 risk 2)
- **Consumer offsets:** Synced every 30s (see doc-19 risk 5) — up to 30s lag

**Action required (CRITICAL SEQUENCE):**

1. **Verify fence on old cluster:** Ensure producers cannot write to southcentralus (NSG rules, DNS cutover, or broker shutdown)
2. **Promote mirror topics to writable:**

   ```bash
   # For each application topic
   kafka-mirrors promote \
     --topics 'app-messages,app-events,app-metrics' \
     --cluster mexicocentral-cluster-link
   ```

   - **Effect:** Removes read-only flag, allows producers to write
   - **Irreversible:** Once promoted, topic is no longer a mirror — cluster link stops replicating

3. **Verify promotion:**

   ```bash
   kafka-topics.sh --bootstrap-server <mexicocentral-broker>:9092 \
     --describe --topic app-messages
   # Check: "Configs: [...] mirror.state=stopped"
   ```

4. **Update producer bootstrap servers:**

   - Change `KAFKA_BOOTSTRAP_SERVERS` env var to mexicocentral broker DNS
   - Restart producer applications (or wait for DNS TTL expiry + connection recycling)

5. **Consumer offset validation:**

   ```bash
   kafka-consumer-groups.sh --bootstrap-server <mexicocentral-broker>:9092 \
     --describe --group web-app-consumer-group
   # Verify LAG is reasonable (≤30s of messages given 30s offset sync interval)
   ```

6. **Resume consumers:**

   - Consumers connect to mexicocentral brokers
   - May reprocess up to 30s of messages (see doc-19 risk 5)

#### 2.2.3 Schema Registry Impact

**Scenario:** `_schemas` topic is mirrored to mexicocentral. SR instance in mexicocentral is running but read-only (cannot register new schemas).

**State:**

- mexicocentral SR reads from `_schemas` mirror topic → has all schemas from southcentralus
- Cannot accept POST/PUT (schema registration) until `_schemas` promoted

**Action required:**

1. **Promote `_schemas` topic FIRST (before application topics):**

   ```bash
   kafka-mirrors promote \
     --topics '_schemas' \
     --cluster mexicocentral-cluster-link
   ```

2. **Restart Schema Registry in mexicocentral:**

   ```bash
   systemctl restart confluent-schema-registry
   ```

   - SR detects `_schemas` is now writable
   - Elects leader (if multiple SR instances)
   - Resumes accepting schema registration

3. **Verify SR is writable:**

   ```bash
   curl -X GET http://sr-01.mexicocentral:8081/subjects
   # Should return list of subjects
   
   # Test schema registration (optional smoke test)
   curl -X POST http://sr-01.mexicocentral:8081/subjects/test-subject/versions \
     -H "Content-Type: application/vnd.schemaregistry.v1+json" \
     -d '{"schema": "{\"type\": \"string\"}"}'
   # Should return schema ID
   ```

4. **Update producer/consumer Schema Registry URL:**

   - Change `SCHEMA_REGISTRY_URL` to mexicocentral SR endpoint
   - Restart applications

**Order dependency:** `_schemas` promotion MUST happen before application topic promotion, otherwise producers that need to register new schemas will fail.

#### 2.2.4 Kafka Connect Impact

**Scenario:** Connect workers in southcentralus dead. Connect internal topics (`connect-configs`, `connect-offsets`, `connect-status`) are mirrored to mexicocentral.

**State:**

- Internal topics are read-only mirrors → workers cannot write state
- Connectors are stopped (no workers running)

**Action required:**

1. **Promote Connect internal topics:**

   ```bash
   kafka-mirrors promote \
     --topics 'connect-configs,connect-offsets,connect-status' \
     --cluster mexicocentral-cluster-link
   ```

2. **Update Connect worker configuration:**

   - Edit `connect-distributed.properties`:

     ```properties
     bootstrap.servers=<mexicocentral-brokers>:9092
     ```

   - If using SASL_SSL, ensure truststore/keystore point to mexicocentral broker certs

3. **Start Connect workers in mexicocentral:**

   ```bash
   systemctl start confluent-kafka-connect
   ```

   - Workers consume `connect-configs`, `connect-offsets`, `connect-status` from beginning
   - Reconstruct connector/task state
   - Resume connectors (may reprocess some data — depends on last committed offset in `connect-offsets`)

4. **Verify connector status:**

   ```bash
   curl -X GET http://kc-01.mexicocentral:8083/connectors
   curl -X GET http://kc-01.mexicocentral:8083/connectors/{name}/status
   ```

5. **Check for reprocessing:**

   - If connectors are source connectors, check for duplicate inserts in destination
   - If connectors are sink connectors, check for gaps (last committed offset may be up to 60s behind actual progress)

**Order dependency:** Connect internal topics MUST be promoted before starting workers.

---

## Part 3: Component Promotion Order

The correct sequence for cross-region failover:

### Phase 1: Pre-Promotion Validation (CRITICAL — prevents split-brain)

1. **Verify old cluster is fenced:**

   - NSG rules block producer traffic to southcentralus Kafka brokers
   - Or DNS has been updated (with confirmation no producers cached old IPs)
   - Or brokers manually stopped: `systemctl stop confluent-kafka` on all southcentralus brokers

2. **Verify cluster link replication lag:**

   ```bash
   kafka-mirrors describe --cluster-link mexicocentral-cluster-link
   # Check "Lag" column — should be <1000 messages for all topics (depends on traffic)
   ```

   - If lag is high, wait for replication to catch up (or accept data loss)

3. **Verify consumer offset sync lag:**

   ```bash
   kafka-consumer-groups.sh --bootstrap-server <mexicocentral-broker>:9092 \
     --describe --group web-app-consumer-group
   # Compare LAG here with LAG on southcentralus (if accessible) — should differ by ≤30s of messages
   ```

### Phase 2: Schema Registry Promotion

**Why first:** Producers need to register schemas before writing messages.

1. **Promote `_schemas` topic:**

   ```bash
   kafka-mirrors promote --topics '_schemas' --cluster mexicocentral-cluster-link
   ```

2. **Restart Schema Registry:**

   ```bash
   systemctl restart confluent-schema-registry
   ```

3. **Validate SR writability:**

   ```bash
   curl -X POST http://sr-01.mexicocentral:8081/config \
     -H "Content-Type: application/vnd.schemaregistry.v1+json" \
     -d '{"compatibility": "BACKWARD"}'
   # Should succeed (200 OK)
   ```

### Phase 3: Kafka Connect Promotion (if used)

**Why before application topics:** Connectors may produce to or consume from application topics — internal state must be writable first.

1. **Promote Connect internal topics:**

   ```bash
   kafka-mirrors promote --topics 'connect-configs,connect-offsets,connect-status' \
     --cluster mexicocentral-cluster-link
   ```

2. **Start Connect workers:**

   ```bash
   systemctl start confluent-kafka-connect
   ```

3. **Validate workers joined:**

   ```bash
   curl -X GET http://kc-01.mexicocentral:8083/ | jq '.kafka_cluster_id'
   # Should return mexicocentral cluster ID
   ```

### Phase 4: Application Topic Promotion

1. **Promote all application topics:**

   ```bash
   kafka-mirrors promote --topics 'app-messages,app-events,app-metrics' \
     --cluster mexicocentral-cluster-link
   ```

2. **Verify promotion:**

   ```bash
   kafka-topics.sh --bootstrap-server <mexicocentral-broker>:9092 --describe
   # Check each topic: should NOT have "mirror" in Configs
   ```

### Phase 5: Producer/Consumer Cutover

1. **Update `KAFKA_BOOTSTRAP_SERVERS` for all producer/consumer applications:**

   - Change DNS or update env var to point to mexicocentral brokers

2. **Update `SCHEMA_REGISTRY_URL`:**

   - Point to mexicocentral Schema Registry

3. **Restart applications** (or wait for DNS TTL expiry + connection recycling)

4. **Monitor for errors:**

   - Check application logs for `NOT_LEADER_FOR_PARTITION` (should auto-retry and succeed)
   - Check for Schema Registry 409 conflicts (indicates schema ID collision — see doc-19 risk 9)

### Phase 6: Validation

1. **Producer health:**

   ```bash
   kafka-console-consumer.sh --bootstrap-server <mexicocentral-broker>:9092 \
     --topic app-messages --from-beginning --max-messages 10
   # Verify new messages appearing
   ```

2. **Consumer lag:**

   ```bash
   kafka-consumer-groups.sh --bootstrap-server <mexicocentral-broker>:9092 \
     --describe --group web-app-consumer-group
   # Verify LAG is decreasing (consumers processing)
   ```

3. **Schema Registry:**

   ```bash
   curl -X GET http://sr-01.mexicocentral:8081/subjects
   # Verify subjects list matches expectations
   ```

4. **Connect status:**

   ```bash
   curl -X GET http://kc-01.mexicocentral:8083/connectors/azure-blob-sink/status | jq '.tasks[].state'
   # Verify all tasks are "RUNNING"
   ```

---

## Part 4: Promotion Command Reference

### 4.1 kafka-mirrors promote

**Purpose:** Convert a read-only mirror topic to a writable independent topic.

**Syntax:**

```bash
kafka-mirrors promote \
  --bootstrap-server <destination-broker>:9092 \
  --topics <topic1,topic2,...> \
  --cluster-link <link-name> \
  [--config-file <props-file>]   # For SASL_SSL auth
```

**Example (with security):**

```bash
kafka-mirrors promote \
  --bootstrap-server mexicocentral-kb-01:9092 \
  --topics '_schemas,app-messages,app-events' \
  --cluster-link southcentralus-to-mexicocentral \
  --command-config /etc/kafka/admin.properties
```

**admin.properties:**

```properties
security.protocol=SASL_SSL
sasl.mechanism=SCRAM-SHA-512
sasl.jaas.config=org.apache.kafka.common.security.scram.ScramLoginModule required username="admin" password="<password>";
ssl.truststore.location=/etc/kafka/ssl/kafka.truststore.jks
ssl.truststore.password=<truststore-password>
```

**Effect:**

- Topic's `mirror.state` config changes from `ACTIVE` to `STOPPED`
- Topic becomes writable
- Cluster link stops replicating this topic
- **Irreversible** — cannot re-establish cluster link for this topic without deleting and recreating it

**Validation:**

```bash
kafka-topics.sh --bootstrap-server <broker>:9092 \
  --describe --topic <topic-name> | grep mirror.state
# Should show "mirror.state=STOPPED" or no mirror.state config (means it's independent)
```

### 4.2 Cluster Link Management

**Describe cluster link:**

```bash
kafka-cluster-links.sh --bootstrap-server <broker>:9092 \
  --command-config /etc/kafka/admin.properties \
  --describe --link <link-name>
```

**List mirror topics:**

```bash
kafka-mirrors.sh --bootstrap-server <broker>:9092 \
  --command-config /etc/kafka/admin.properties \
  --list --link <link-name>
```

**Pause cluster link (emergency stop replication):**

```bash
kafka-cluster-links.sh --bootstrap-server <broker>:9092 \
  --command-config /etc/kafka/admin.properties \
  --alter --link <link-name> --state PAUSED
```

### 4.3 Schema Registry Leader Election

**Check SR mode:**

```bash
curl -X GET http://sr-01:8081/mode
# Response: {"mode":"READWRITE"} or {"mode":"READONLY"}
```

**Force SR mode (emergency):**

```bash
curl -X PUT http://sr-01:8081/mode \
  -H "Content-Type: application/json" \
  -d '{"mode":"READWRITE"}'
# NOT RECOMMENDED — prefer promoting _schemas topic instead
```

**Check SR leader:**

Schema Registry does not expose a "leader" endpoint in OSS version. Leader is determined by Kafka consumer group assignment for `_schemas` topic. To infer leader:

- POST a new schema → succeeds = this instance is leader
- Or check SR logs: `grep -i "Elected as leader" /var/log/confluent/schema-registry.log`

### 4.4 Kafka Connect Task Management

**Restart failed connector:**

```bash
curl -X POST http://kc-01:8083/connectors/{name}/restart
```

**Restart specific task:**

```bash
curl -X POST http://kc-01:8083/connectors/{name}/tasks/{task-id}/restart
```

**Pause connector (stop processing but keep config):**

```bash
curl -X PUT http://kc-01:8083/connectors/{name}/pause
```

**Resume connector:**

```bash
curl -X PUT http://kc-01:8083/connectors/{name}/resume
```

---

## Part 5: ZooKeeper-Specific Concerns

### 5.1 Quorum Loss Scenarios

**3-node ensemble:**

| Scenario | Nodes Up | Quorum? | ZK Status | Kafka Impact |
|---|---|---|---|---|
| All healthy | 3/3 | ✅ Yes (3 ≥ 2) | Leader active | Normal |
| 1 node down | 2/3 | ✅ Yes (2 ≥ 2) | Leader re-election if leader died | Brief pause, then normal |
| 2 nodes down | 1/3 | ❌ No (1 < 2) | Read-only, no leader | **Cluster metadata frozen** |

**5-node ensemble:**

| Scenario | Nodes Up | Quorum? | ZK Status | Kafka Impact |
|---|---|---|---|---|
| All healthy | 5/5 | ✅ Yes (5 ≥ 3) | Leader active | Normal |
| 1 node down | 4/5 | ✅ Yes (4 ≥ 3) | Normal | Normal |
| 2 nodes down | 3/5 | ✅ Yes (3 ≥ 3) | Normal | Normal |
| 3 nodes down | 2/5 | ❌ No (2 < 3) | Read-only, no leader | **Cluster metadata frozen** |

**Recommendation for multi-AZ:**

- Deploy ZK ensemble across ≥3 AZs (or 2 AZs + 1 cross-region)
- For dev (2 AZs only), accept risk: losing Zone 1 (2 nodes) = quorum loss = outage

**Recommendation for multi-region:**

- Run **independent ZK ensembles per region** (do NOT span ZK across regions)
- Each Kafka cluster has its own 3-node ZK ensemble within the region
- Cross-region failover uses cluster linking (not ZK replication)

### 5.2 ZooKeeper Ephemeral Nodes and Broker Liveness

**Mechanism:**

- Brokers register ephemeral nodes in ZK: `/brokers/ids/{broker.id}`
- ZK requires heartbeat every `tickTime * syncLimit` ms (default: 2000 * 2 = 4000ms)
- If ZK doesn't receive heartbeat → deletes ephemeral node → broker considered dead

**Failure scenarios:**

1. **Broker process dies cleanly (`systemctl stop`):**

   - Broker sends controlled shutdown request to controller
   - Controller reassigns partition leaders gracefully
   - Ephemeral node deleted immediately
   - Downtime: 0-1s per partition

2. **Broker VM dies (hard kill, network partition):**

   - ZK session times out after `zookeeper.session.timeout.ms` (default 18000ms)
   - Controller detects broker death after timeout
   - Ephemeral node deleted
   - Downtime: 18-20s per partition (until new leaders elected)

3. **ZK quorum lost (broker still running):**

   - Broker cannot update metadata in ZK
   - Existing partition leaders continue serving (cached metadata)
   - No new leaders can be elected
   - No new brokers can join
   - **Degraded mode:** Cluster works until a partition leader dies, then that partition is stuck

**Mitigation:**

- Set `controlled.shutdown.enable=true` (already set in our config)
- Tune `zookeeper.session.timeout.ms` (default 18000ms is reasonable)
- Monitor ZK ensemble health aggressively

### 5.3 ZK Ensemble Recovery from Quorum Loss

**Scenario:** 3-node ensemble, 2 nodes dead, quorum lost.

**Option 1: Restart dead nodes (preferred):**

1. Fix underlying issue (VM restart, network restore)
2. Start ZK service: `systemctl start confluent-zookeeper`
3. Ensemble re-forms quorum automatically
4. Kafka brokers reconnect, resume normal operation

**Option 2: Force reconfiguration (emergency only):**

If 2/3 nodes are permanently lost, manually reconfigure to 1-node ensemble:

1. **On surviving node:**

   Edit `zookeeper.properties`, remove dead servers:

   ```properties
   # Before:
   server.1=zk-01:2888:3888
   server.2=zk-02:2888:3888
   server.3=zk-03:2888:3888
   
   # After:
   server.1=zk-01:2888:3888
   ```

2. **Restart ZK:**

   ```bash
   systemctl restart confluent-zookeeper
   ```

3. **Risk:** Data loss if surviving node was not leader or had stale data.

**Option 3: Restore from snapshot:**

1. Stop all ZK nodes
2. Copy snapshot from backup: `cp /backup/zookeeper-snapshot.* /data/zookeeper/data/version-2/`
3. Start ZK with reduced ensemble (1 or 2 nodes)
4. Kafka cluster will lose any metadata written since snapshot

---

## Part 6: Rollback and Failback

### 6.1 Rollback (Pre-Promotion Abort)

**If failover initiated but promotion not yet executed:**

1. **Cancel DNS cutover** (revert to old cluster)
2. **Do not promote mirrors**
3. **Resume traffic on old cluster** (if it recovered)

**Risk:** None — mirrors remain mirrors, old cluster remains authoritative.

### 6.2 Failback (Post-Promotion Re-Reverse)

**If failover completed (mirrors promoted in mexicocentral), and southcentralus recovers:**

**Problem:** Promotion is **irreversible** per topic — you cannot un-promote and resume replication. The old cluster link is broken for promoted topics.

**Options:**

1. **Keep mexicocentral as primary** (recommended):

   - Treat southcentralus as the new DR region
   - Create new cluster link: mexicocentral → southcentralus
   - Mirror topics back to southcentralus
   - Do NOT fail back unless necessary

2. **Re-reverse replication (complex):**

   - Delete promoted topics in southcentralus (or create new names)
   - Create cluster link: mexicocentral → southcentralus
   - Mirror topics from mexicocentral to southcentralus
   - After catching up, fence mexicocentral, promote mirrors in southcentralus, cut over
   - **Downtime:** 5-30 minutes depending on data volume

3. **Accept divergence (disaster scenario):**

   - If both clusters were writable simultaneously (split-brain), data is permanently diverged
   - Manual data reconciliation required (application-specific)

**Recommendation:** Treat failover as a **one-way operation** for a given incident. Plan for reverse replication in the next maintenance window, not during live failover.

---

## Part 7: Automation Recommendations

### 7.1 Ansible Playbook Structure

**Proposed playbook:** `ansible/playbooks/failover-promote.yml`

```yaml
---
- name: Failover Promotion — Cluster Linking
  hosts: localhost
  gather_facts: false
  vars:
    source_cluster: southcentralus
    dest_cluster: mexicocentral
    cluster_link_name: "{{ source_cluster }}-to-{{ dest_cluster }}"
    admin_properties: /etc/kafka/admin.properties
  tasks:
    # Pre-flight checks
    - name: Verify fence on source cluster
      # TODO: Check NSG rules, or broker liveness
      
    - name: Verify replication lag
      # TODO: kafka-mirrors describe, parse lag
      
    # Phase 2: Schema Registry
    - name: Promote _schemas topic
      ansible.builtin.shell: |
        kafka-mirrors promote \
          --bootstrap-server {{ dest_bootstrap }} \
          --topics '_schemas' \
          --cluster-link {{ cluster_link_name }} \
          --command-config {{ admin_properties }}
      
    - name: Restart Schema Registry
      ansible.builtin.systemd:
        name: confluent-schema-registry
        state: restarted
      delegate_to: "{{ groups['schema_registry'][0] }}"
      
    # Phase 3: Kafka Connect (if enabled)
    - name: Promote Connect internal topics
      ansible.builtin.shell: |
        kafka-mirrors promote \
          --bootstrap-server {{ dest_bootstrap }} \
          --topics 'connect-configs,connect-offsets,connect-status' \
          --cluster-link {{ cluster_link_name }} \
          --command-config {{ admin_properties }}
      when: kafka_connect_enabled | default(false)
      
    - name: Start Connect workers
      ansible.builtin.systemd:
        name: confluent-kafka-connect
        state: started
      delegate_to: "{{ item }}"
      loop: "{{ groups['kafka_connect'] }}"
      when: kafka_connect_enabled | default(false)
      
    # Phase 4: Application topics
    - name: Promote application topics
      ansible.builtin.shell: |
        kafka-mirrors promote \
          --bootstrap-server {{ dest_bootstrap }} \
          --topics '{{ application_topics | join(",") }}' \
          --cluster-link {{ cluster_link_name }} \
          --command-config {{ admin_properties }}
      vars:
        application_topics:
          - app-messages
          - app-events
          - app-metrics
      
    # Validation
    - name: Verify topic promotion
      # TODO: kafka-topics.sh --describe, check mirror.state
```

### 7.2 Idempotency Considerations

- `kafka-mirrors promote` is **not idempotent** — running twice on already-promoted topic fails
- Playbook should check topic state before promoting:

  ```bash
  kafka-topics.sh --describe --topic <topic> | grep -q "mirror.state" || echo "already promoted"
  ```

### 7.3 Automated Testing (SP9 Chaos Studio)

**Planned chaos experiments:**

1. **AZ failure simulation:** Shut down all VMs in Zone 1, verify automatic controller/partition leader failover
2. **ZK quorum loss:** Stop 2/3 ZK nodes, verify cluster enters read-only mode, monitor producer errors
3. **Cross-region failover:** Manually trigger `failover-promote.yml` playbook, verify producer/consumer cutover, measure downtime (target: <2 minutes)
4. **Schema Registry promotion:** Promote `_schemas`, verify new schema registration works
5. **Split-brain prevention:** Attempt dual-write to old and new cluster, verify fencing prevents it

---

## Part 8: Monitoring and Observability

### 8.1 Pre-Failover Metrics

**ZooKeeper:**

- `zk_quorum_size` (expect 3)
- `zk_live_nodes` (expect 3)
- `zk_outstanding_requests` (expect <10, spike = slowness)

**Kafka:**

- `kafka.controller:type=KafkaController,name=ActiveControllerCount` (expect 1 cluster-wide)
- `kafka.server:type=ReplicaManager,name=UnderReplicatedPartitions` (expect 0)
- `kafka.server:type=ReplicaManager,name=OfflineReplicaCount` (expect 0)

**Cluster Linking:**

- `confluent.cluster_link:type=ClusterLinkFetcherManager,name=ReplicationBytesPerSec` (expect >0 if traffic exists)
- `confluent.cluster_link:type=ClusterLinkFetcherManager,name=ReplicationLag` (expect <1000 messages)

### 8.2 During-Failover Metrics

**Producer:**

- `kafka.producer:type=producer-metrics,client-id=*,name=request-latency-avg` (expect spike during leader election)
- `kafka.producer:type=producer-metrics,client-id=*,name=record-error-rate` (expect brief spike, then 0)

**Consumer:**

- `kafka.consumer:type=consumer-fetch-manager-metrics,client-id=*,name=fetch-latency-avg` (expect spike during metadata refresh)
- `kafka.consumer:type=consumer-coordinator-metrics,client-id=*,name=commit-latency-avg` (expect spike during rebalance)

### 8.3 Post-Failover Metrics

**Validation:**

- `kafka.server:type=BrokerTopicMetrics,name=MessagesInPerSec` (expect >0 on promoted topics)
- `kafka.server:type=BrokerTopicMetrics,name=BytesInPerSec` (expect >0)
- Schema Registry: `/metrics` endpoint, check `master_slave_role` (expect "master" on promoted instance)
- Kafka Connect: `/connectors/{name}/status` (expect `state=RUNNING` for all tasks)

---

## Part 9: Decision Summary

### Intra-AZ Failover (Zone 1 → Zone 2)

**Automatic components:**

- Kafka brokers (controller election, partition leader election) — **0-5s downtime**
- Schema Registry (leader election) — **1-10s downtime**
- Kafka Connect (task reassignment) — **5-30s downtime**

**Manual components:**

- ZooKeeper quorum restoration (if quorum lost) — **requires manual intervention**

**Action required:** Monitor ISR, replace dead broker VMs, reassign partitions to restore replication factor.

### Cross-Region Failover (southcentralus → mexicocentral)

**Manual orchestration required (all components):**

1. **Fence old cluster** (NSG, DNS, or broker shutdown)
2. **Promote `_schemas`** (Schema Registry dependency)
3. **Restart Schema Registry**
4. **Promote Connect internal topics** (if using Connect)
5. **Start Connect workers**
6. **Promote application topics**
7. **Cut over producer/consumer DNS**
8. **Validate end-to-end traffic**

**Estimated downtime:** 2-5 minutes (mostly DNS propagation + connection recycling)

**Irreversibility:** Promoted topics cannot be un-promoted — failback requires new cluster link in reverse direction.

---

## Appendices

### A. Configuration Tuning for Faster Failover

**Kafka broker:**

```properties
# Faster leader election
leader.imbalance.check.interval.seconds=30  # default 300
auto.leader.rebalance.enable=true

# Faster broker death detection
zookeeper.session.timeout.ms=6000  # default 18000, min 2 * tickTime
```

**Producer:**

```properties
# Faster metadata refresh
metadata.max.age.ms=30000  # default 300000
connections.max.idle.ms=60000  # default 540000

# Aggressive retries
retries=2147483647  # infinite
retry.backoff.ms=100  # default 100
request.timeout.ms=10000  # default 30000
```

**Consumer:**

```properties
# Faster rebalance
session.timeout.ms=6000  # default 10000
heartbeat.interval.ms=2000  # default 3000
max.poll.interval.ms=60000  # default 300000

# Faster metadata refresh
metadata.max.age.ms=30000  # default 300000
```

### B. Glossary

- **ISR:** In-Sync Replicas — replicas that are caught up to the leader's log
- **HWM:** High Water Mark — the highest offset visible to consumers (last offset replicated to all ISR members)
- **LEO:** Log End Offset — the highest offset in a replica's log (may be ahead of HWM)
- **PID:** Producer ID — unique identifier for idempotent producers (per-cluster)
- **Epoch:** Producer or consumer generation number (increments on session restart)
- **Quorum:** Minimum number of nodes required for consensus (floor(N/2) + 1)
- **Mirror topic:** A read-only replica topic created by Cluster Linking
- **Promotion:** Converting a mirror topic to a writable independent topic (irreversible)

---

**Next Steps:**

1. **SP8:** Implement multi-region cluster linking config in Terraform + Ansible
2. **SP9:** Automate failover playbook (`failover-promote.yml`) and test in Chaos Studio
3. **SP9:** Add Prometheus alerts for ZK quorum loss, under-replicated partitions, replication lag
4. **SP9:** Document failback procedures (reverse cluster linking setup)

**Decisions Required:**

- [ ] ZooKeeper ensemble topology for production (3 nodes per region vs cross-region quorum)
- [ ] Acceptable replication lag threshold for auto-promotion (manual vs automated failover decision)
- [ ] Failback vs accept-new-primary strategy (operational complexity vs data locality)
