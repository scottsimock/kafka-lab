#!/usr/bin/env bash
# Cluster Linking Setup
# Links primary (southcentralus) to secondary (mexicocentral) for DR

PRIMARY_BOOTSTRAP="broker-1.kafka.internal:9092"
SECONDARY_BOOTSTRAP="broker-4.kafka.secondary:9092"
LINK_NAME="primary-to-secondary"

# =====================================================
# Step 1: Create cluster link on destination cluster
# =====================================================

# Create the link configuration file
cat > /tmp/cluster-link.properties << 'EOF'
bootstrap.servers=broker-1.kafka.internal:9092,broker-2.kafka.internal:9092,broker-3.kafka.internal:9092
security.protocol=PLAINTEXT
# For SSL connections:
# security.protocol=SSL
# ssl.truststore.location=/etc/kafka/ssl/kafka.truststore.jks
# ssl.truststore.password=${TRUSTSTORE_PASSWORD}
EOF

# Create the cluster link on the secondary (destination) cluster
kafka-cluster-links --bootstrap-server "$SECONDARY_BOOTSTRAP" \
  --create \
  --link "$LINK_NAME" \
  --config-file /tmp/cluster-link.properties

# =====================================================
# Step 2: Create mirror topics on destination
# =====================================================

# Mirror a specific topic
kafka-mirrors --create \
  --mirror-topic orders \
  --link "$LINK_NAME" \
  --bootstrap-server "$SECONDARY_BOOTSTRAP"

# Mirror multiple topics with a pattern
kafka-mirrors --create \
  --mirror-topic events \
  --link "$LINK_NAME" \
  --bootstrap-server "$SECONDARY_BOOTSTRAP"

# =====================================================
# Step 3: Verify cluster link status
# =====================================================

# List all cluster links
kafka-cluster-links --bootstrap-server "$SECONDARY_BOOTSTRAP" --list

# Describe link status (check lag and health)
kafka-cluster-links --bootstrap-server "$SECONDARY_BOOTSTRAP" \
  --describe \
  --link "$LINK_NAME"

# List mirror topics
kafka-mirrors --describe \
  --link "$LINK_NAME" \
  --bootstrap-server "$SECONDARY_BOOTSTRAP"

# =====================================================
# Step 4: Failover (promote mirror to writable topic)
# =====================================================

# Stop the mirror (promote to independent topic)
# Use during DR failover
# kafka-mirrors --failover \
#   --topics orders \
#   --bootstrap-server "$SECONDARY_BOOTSTRAP"

# Or promote gracefully (waits for replication to catch up)
# kafka-mirrors --promote \
#   --topics orders \
#   --bootstrap-server "$SECONDARY_BOOTSTRAP"

# =====================================================
# Cleanup
# =====================================================
rm -f /tmp/cluster-link.properties
