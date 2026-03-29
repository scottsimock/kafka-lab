"""Kafka Producer with delivery callbacks and error handling.
Uses confluent-kafka library with librdkafka backend.
"""

import json
import logging
import os
import socket
from confluent_kafka import Producer, KafkaError, KafkaException

logging.basicConfig(level=logging.INFO)
logger = logging.getLogger(__name__)


def get_producer_config() -> dict:
    """Build producer configuration from environment variables."""
    return {
        "bootstrap.servers": os.environ.get(
            "KAFKA_BOOTSTRAP_SERVERS", "localhost:9092"
        ),
        "client.id": socket.gethostname(),
        "acks": "all",
        "compression.type": "lz4",
        "linger.ms": 10,
        "retries": 3,
        "retry.backoff.ms": 100,
        "enable.idempotence": True,
    }


def delivery_callback(err, msg):
    """Called once per message to indicate delivery result."""
    if err is not None:
        logger.error(
            "Message delivery failed: topic=%s partition=%s error=%s",
            msg.topic(),
            msg.partition(),
            err,
        )
    else:
        logger.debug(
            "Message delivered: topic=%s partition=%s offset=%s",
            msg.topic(),
            msg.partition(),
            msg.offset(),
        )


def produce_messages(topic: str, messages: list[dict]) -> int:
    """Produce a list of messages to a Kafka topic.

    Args:
        topic: Target Kafka topic name.
        messages: List of dicts with optional 'key' and required 'value' fields.

    Returns:
        Number of successfully queued messages.
    """
    producer = Producer(get_producer_config())
    queued = 0

    try:
        for msg in messages:
            key = msg.get("key")
            value = json.dumps(msg["value"]).encode("utf-8")
            key_bytes = key.encode("utf-8") if key else None

            producer.produce(
                topic=topic,
                key=key_bytes,
                value=value,
                callback=delivery_callback,
            )
            queued += 1

            # Serve delivery callbacks periodically
            producer.poll(0)

    except KafkaException as e:
        logger.error("Kafka error: %s", e)
        raise
    finally:
        remaining = producer.flush(timeout=30)
        if remaining > 0:
            logger.warning("%d messages were not delivered", remaining)

    return queued


if __name__ == "__main__":
    sample_messages = [
        {"key": "order-1", "value": {"product": "widget", "quantity": 5}},
        {"key": "order-2", "value": {"product": "gadget", "quantity": 3}},
    ]
    count = produce_messages("orders", sample_messages)
    logger.info("Queued %d messages", count)
