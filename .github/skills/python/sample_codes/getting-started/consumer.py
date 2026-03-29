"""Kafka Consumer with manual offset commits and graceful shutdown.
Uses confluent-kafka library with librdkafka backend.
"""

import json
import logging
import os
import signal
from confluent_kafka import Consumer, KafkaError, KafkaException

logging.basicConfig(level=logging.INFO)
logger = logging.getLogger(__name__)

# Graceful shutdown flag
_shutdown = False


def signal_handler(signum, frame):
    global _shutdown
    logger.info("Shutdown signal received")
    _shutdown = True


signal.signal(signal.SIGINT, signal_handler)
signal.signal(signal.SIGTERM, signal_handler)


def get_consumer_config() -> dict:
    """Build consumer configuration from environment variables."""
    return {
        "bootstrap.servers": os.environ.get(
            "KAFKA_BOOTSTRAP_SERVERS", "localhost:9092"
        ),
        "group.id": os.environ.get("KAFKA_CONSUMER_GROUP", "my-consumer-group"),
        "auto.offset.reset": "earliest",
        "enable.auto.commit": False,
        "session.timeout.ms": 30000,
        "heartbeat.interval.ms": 10000,
        "max.poll.interval.ms": 300000,
    }


def process_message(msg) -> bool:
    """Process a single Kafka message.

    Returns:
        True if processing succeeded, False otherwise.
    """
    try:
        key = msg.key().decode("utf-8") if msg.key() else None
        value = json.loads(msg.value().decode("utf-8"))

        logger.info(
            "Processing: topic=%s partition=%d offset=%d key=%s",
            msg.topic(),
            msg.partition(),
            msg.offset(),
            key,
        )

        # Application-specific processing logic here
        logger.debug("Message value: %s", value)
        return True

    except (json.JSONDecodeError, UnicodeDecodeError) as e:
        logger.error("Failed to deserialize message: %s", e)
        return False


def consume_loop(topics: list[str]):
    """Main consumer loop with manual offset commits."""
    consumer = Consumer(get_consumer_config())

    try:
        consumer.subscribe(topics)
        logger.info("Subscribed to topics: %s", topics)

        while not _shutdown:
            msg = consumer.poll(timeout=1.0)

            if msg is None:
                continue

            if msg.error():
                if msg.error().code() == KafkaError._PARTITION_EOF:
                    logger.debug(
                        "Reached end of partition: %s [%d]",
                        msg.topic(),
                        msg.partition(),
                    )
                else:
                    raise KafkaException(msg.error())
                continue

            success = process_message(msg)

            if success:
                consumer.commit(msg, asynchronous=False)

    except KafkaException as e:
        logger.error("Consumer error: %s", e)
        raise
    finally:
        consumer.close()
        logger.info("Consumer closed cleanly")


if __name__ == "__main__":
    consume_loop(["orders", "events"])
