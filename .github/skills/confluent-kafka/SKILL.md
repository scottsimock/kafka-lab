---
name: confluent-kafka
description: Deploy and manage Confluent Kafka Platform on Azure VMs. Use when agents need to configure Kafka brokers, ZooKeeper, Schema Registry, Kafka Connect, cluster linking, or manage topics, partitions, and replication across multi-region deployments.
---

# Confluent Kafka

Confluent Platform is an enterprise streaming platform built on Apache Kafka. It extends Kafka with Schema Registry, Kafka Connect, cluster linking, and management tools. In this project, Confluent Platform runs on Azure VMs across multiple regions and availability zones for resiliency testing.

## Architecture

```text
┌─────────────────────────────────────────────────────┐
│ Region: southcentralus (Primary)                     │
│  ┌─────────────┐  ┌─────────────┐  ┌─────────────┐ │
│  │ Broker 1    │  │ Broker 2    │  │ Broker 3    │ │
│  │ Zone 1      │  │ Zone 2      │  │ Zone 1      │ │
│  └─────────────┘  └─────────────┘  └─────────────┘ │
│  ┌──────────────────────────────────────────────┐   │
│  │ ZooKeeper Ensemble (3 nodes)                 │   │
│  └──────────────────────────────────────────────┘   │
│  ┌──────────────┐  ┌───────────────┐                │
│  │ Schema Reg.  │  │ Kafka Connect │                │
│  └──────────────┘  └───────────────┘                │
├─────────────────────────────────────────────────────┤
│ Region: mexicocentral (Secondary)                    │
│  ┌─────────────┐  ┌─────────────┐  ┌─────────────┐ │
│  │ Broker 4    │  │ Broker 5    │  │ Broker 6    │ │
│  └─────────────┘  └─────────────┘  └─────────────┘ │
│       ↑ Cluster Linking from Primary                 │
└─────────────────────────────────────────────────────┘
```

## Key Components

### Kafka Brokers

Brokers store and serve messages. Each broker has a unique `broker.id` and manages partitions. Brokers replicate data across the cluster for fault tolerance. For production, use a minimum of 3 brokers with replication factor 3.

### ZooKeeper

Manages cluster metadata, broker registration, and leader election. Deploy as a 3-node ensemble for quorum. ZooKeeper nodes should be on separate VMs from brokers in production.

### Schema Registry

Centralized schema management for Avro, Protobuf, and JSON Schema. Validates message schemas at produce time, enforces compatibility rules, and provides a REST API. Deploy with at least 2 instances for HA.

### Kafka Connect

Scalable framework for connecting Kafka to external systems (databases, cloud storage, etc.) via source and sink connectors. Runs in distributed mode with worker nodes.

### Cluster Linking

Native data replication between Kafka clusters without MirrorMaker. Provides lower latency, automatic offset translation, and consumer group migration. Used for cross-region DR and data sharing.

## Broker Configuration

See [getting-started/server.properties](sample_codes/getting-started/server.properties) for a complete broker configuration.

### Critical Settings

| Setting | Purpose | Recommended |
|---|---|---|
| `broker.id` | Unique broker identifier | Explicit integer per broker |
| `listeners` | Bind address and protocol | Named listeners with security |
| `advertised.listeners` | Client-facing address | Network-resolvable hostname |
| `log.dirs` | Message storage directories | Dedicated fast disks |
| `default.replication.factor` | Default replicas | `3` for production |
| `num.partitions` | Default partitions | `6` minimum |
| `min.insync.replicas` | Write durability | `2` with replication factor 3 |
| `inter.broker.listener.name` | Internal communication | Internal-only listener |

## Ansible Deployment

See [common-patterns/broker-config.yml](sample_codes/common-patterns/broker-config.yml) for an Ansible playbook that deploys and configures Kafka brokers.

## Common Patterns

### Topic Management

See [common-patterns/topic-management.sh](sample_codes/common-patterns/topic-management.sh) for CLI commands to create, describe, and manage topics.

### Cluster Linking

See [common-patterns/cluster-linking.sh](sample_codes/common-patterns/cluster-linking.sh) for setting up cluster linking between primary and secondary regions.

## Port Reference

| Service | Port | Protocol |
|---|---|---|
| Kafka Broker (internal) | 9092 | PLAINTEXT |
| Kafka Broker (external) | 9093 | SSL |
| ZooKeeper client | 2181 | TCP |
| ZooKeeper peer | 2888 | TCP |
| ZooKeeper election | 3888 | TCP |
| Schema Registry | 8081 | HTTP/HTTPS |
| Kafka Connect REST | 8083 | HTTP/HTTPS |
| REST Proxy | 8082 | HTTP/HTTPS |

## Best Practices

- **Do**: Use replication factor 3 with `min.insync.replicas=2`
- **Do**: Use named listeners with SSL for external access
- **Do**: Place brokers across availability zones for HA
- **Do**: Use dedicated disks for Kafka log directories
- **Do**: Enable Schema Registry validation for data quality
- **Do**: Use cluster linking for cross-region replication
- **Avoid**: ZooKeeper and brokers on the same VM in production
- **Avoid**: Replication factor 1 for any production topic
- **Avoid**: Overly high partition counts (resource overhead)

## Troubleshooting

| Issue | Solution |
|---|---|
| Under-replicated partitions | Check broker health, disk space, and network connectivity |
| Consumer lag increasing | Scale consumers, check processing time, verify no rebalances |
| Schema Registry 409 | Schema compatibility violation; review schema evolution rules |
| Cluster linking lag | Check network latency between regions; verify listener config |

## Learn More

| Topic | Reference |
|---|---|
| Confluent Platform docs | [docs.confluent.io/platform/current](https://docs.confluent.io/platform/current/platform.html) |
| Broker configuration | [Broker Config Reference](https://docs.confluent.io/platform/current/installation/configuration/broker-configs.html) |
| Schema Registry | [Schema Registry docs](https://docs.confluent.io/platform/current/schema-registry/index.html) |
| Cluster Linking | [Cluster Linking Overview](https://docs.confluent.io/platform/current/multi-dc-deployments/cluster-linking/overview.html) |
| Kafka Connect | [Connect docs](https://docs.confluent.io/platform/current/connect/index.html) |
| Python client | [confluent-kafka-python](https://docs.confluent.io/kafka-clients/python/current/overview.html) |
