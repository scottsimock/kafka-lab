#!/usr/bin/env bash
# Kafka Topic Management Commands
# Common CLI operations for creating, describing, and managing topics

BOOTSTRAP="broker-1.kafka.internal:9092"

# =====================================================
# Create Topics
# =====================================================

# Create a topic with specific partitions and replication
kafka-topics --bootstrap-server "$BOOTSTRAP" \
  --create \
  --topic orders \
  --partitions 12 \
  --replication-factor 3 \
  --config min.insync.replicas=2 \
  --config retention.ms=604800000

# Create a compacted topic for state
kafka-topics --bootstrap-server "$BOOTSTRAP" \
  --create \
  --topic user-profiles \
  --partitions 6 \
  --replication-factor 3 \
  --config cleanup.policy=compact \
  --config min.cleanable.dirty.ratio=0.1

# =====================================================
# Describe Topics
# =====================================================

# List all topics
kafka-topics --bootstrap-server "$BOOTSTRAP" --list

# Describe a specific topic
kafka-topics --bootstrap-server "$BOOTSTRAP" \
  --describe \
  --topic orders

# Show under-replicated partitions
kafka-topics --bootstrap-server "$BOOTSTRAP" \
  --describe \
  --under-replicated-partitions

# =====================================================
# Alter Topics
# =====================================================

# Increase partitions (cannot decrease)
kafka-topics --bootstrap-server "$BOOTSTRAP" \
  --alter \
  --topic orders \
  --partitions 24

# Update topic configuration
kafka-configs --bootstrap-server "$BOOTSTRAP" \
  --entity-type topics \
  --entity-name orders \
  --alter \
  --add-config retention.ms=259200000

# =====================================================
# Consumer Groups
# =====================================================

# List consumer groups
kafka-consumer-groups --bootstrap-server "$BOOTSTRAP" --list

# Describe a consumer group (shows lag)
kafka-consumer-groups --bootstrap-server "$BOOTSTRAP" \
  --describe \
  --group my-consumer-group

# Reset offsets to earliest
kafka-consumer-groups --bootstrap-server "$BOOTSTRAP" \
  --group my-consumer-group \
  --topic orders \
  --reset-offsets \
  --to-earliest \
  --execute

# =====================================================
# Produce and Consume (testing)
# =====================================================

# Produce test messages
echo '{"test": "message"}' | kafka-console-producer \
  --bootstrap-server "$BOOTSTRAP" \
  --topic orders

# Consume from beginning
kafka-console-consumer \
  --bootstrap-server "$BOOTSTRAP" \
  --topic orders \
  --from-beginning \
  --max-messages 10
