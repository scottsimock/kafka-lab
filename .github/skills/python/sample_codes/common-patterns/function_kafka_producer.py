"""Azure Function that produces messages to Kafka.
HTTP-triggered function using the Python v2 programming model.
"""

import azure.functions as func
import json
import logging
import os
from confluent_kafka import Producer

app = func.FunctionApp()

logger = logging.getLogger(__name__)

# Reuse producer across invocations for connection pooling
_producer = None


def get_producer() -> Producer:
    """Get or create a shared Kafka producer instance."""
    global _producer
    if _producer is None:
        _producer = Producer(
            {
                "bootstrap.servers": os.environ["KAFKA_BOOTSTRAP_SERVERS"],
                "acks": "all",
                "compression.type": "lz4",
                "linger.ms": 5,
                "enable.idempotence": True,
            }
        )
    return _producer


@app.route("produce/{topic}", methods=["POST"])
def produce_to_topic(req: func.HttpRequest) -> func.HttpResponse:
    """Produce a message to a specified Kafka topic.

    URL: POST /api/produce/{topic}
    Body: {"key": "optional-key", "value": {...}}
    """
    topic = req.route_params.get("topic")
    if not topic:
        return func.HttpResponse(
            json.dumps({"error": "Topic name is required"}),
            status_code=400,
            mimetype="application/json",
        )

    try:
        body = req.get_json()
    except ValueError:
        return func.HttpResponse(
            json.dumps({"error": "Request body must be valid JSON"}),
            status_code=400,
            mimetype="application/json",
        )

    if "value" not in body:
        return func.HttpResponse(
            json.dumps({"error": "Missing required field: value"}),
            status_code=400,
            mimetype="application/json",
        )

    producer = get_producer()
    key = body.get("key", "").encode("utf-8") if body.get("key") else None
    value = json.dumps(body["value"]).encode("utf-8")

    try:
        producer.produce(topic=topic, key=key, value=value)
        producer.flush(timeout=10)
    except Exception as e:
        logger.error("Failed to produce message: %s", e)
        return func.HttpResponse(
            json.dumps({"error": f"Failed to produce: {e}"}),
            status_code=500,
            mimetype="application/json",
        )

    return func.HttpResponse(
        json.dumps(
            {
                "status": "produced",
                "topic": topic,
                "key": body.get("key"),
            }
        ),
        status_code=201,
        mimetype="application/json",
    )
