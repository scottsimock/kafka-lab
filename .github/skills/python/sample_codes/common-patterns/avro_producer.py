"""Avro producer with Schema Registry integration.
Produces Avro-encoded messages validated against a registered schema.
"""

import json
import logging
import os
from confluent_kafka import Producer
from confluent_kafka.schema_registry import SchemaRegistryClient
from confluent_kafka.schema_registry.avro import AvroSerializer
from confluent_kafka.serialization import (
    SerializationContext,
    MessageField,
    StringSerializer,
)

logging.basicConfig(level=logging.INFO)
logger = logging.getLogger(__name__)

# Avro schema for order events
ORDER_SCHEMA = json.dumps(
    {
        "type": "record",
        "name": "Order",
        "namespace": "com.kafkalab.events",
        "fields": [
            {"name": "order_id", "type": "string"},
            {"name": "product", "type": "string"},
            {"name": "quantity", "type": "int"},
            {"name": "price", "type": "double"},
            {"name": "timestamp", "type": "long", "logicalType": "timestamp-millis"},
        ],
    }
)


def order_to_dict(order, ctx):
    """Convert an order object to a dict for Avro serialization."""
    return {
        "order_id": order["order_id"],
        "product": order["product"],
        "quantity": order["quantity"],
        "price": order["price"],
        "timestamp": order["timestamp"],
    }


def create_avro_producer() -> tuple[Producer, AvroSerializer, StringSerializer]:
    """Create a Kafka producer with Avro serialization."""
    schema_registry_url = os.environ.get(
        "SCHEMA_REGISTRY_URL", "http://localhost:8081"
    )

    schema_registry_client = SchemaRegistryClient({"url": schema_registry_url})

    avro_serializer = AvroSerializer(
        schema_registry_client,
        ORDER_SCHEMA,
        order_to_dict,
        conf={"auto.register.schemas": True},
    )

    string_serializer = StringSerializer("utf_8")

    producer = Producer(
        {
            "bootstrap.servers": os.environ.get(
                "KAFKA_BOOTSTRAP_SERVERS", "localhost:9092"
            ),
            "acks": "all",
            "enable.idempotence": True,
        }
    )

    return producer, avro_serializer, string_serializer


def produce_order(topic: str, order: dict):
    """Produce an Avro-encoded order message."""
    producer, avro_serializer, string_serializer = create_avro_producer()

    producer.produce(
        topic=topic,
        key=string_serializer(order["order_id"]),
        value=avro_serializer(
            order, SerializationContext(topic, MessageField.VALUE)
        ),
    )
    producer.flush()
    logger.info("Produced order: %s", order["order_id"])


if __name__ == "__main__":
    import time

    sample_order = {
        "order_id": "ORD-001",
        "product": "widget",
        "quantity": 5,
        "price": 29.99,
        "timestamp": int(time.time() * 1000),
    }
    produce_order("orders-avro", sample_order)
