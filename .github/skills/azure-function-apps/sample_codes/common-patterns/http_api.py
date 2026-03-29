"""HTTP API pattern for Azure Functions
RESTful endpoint with route parameters, input validation, and JSON responses.
"""

import azure.functions as func
import json
import logging

app = func.FunctionApp()


@app.route("topics", methods=["GET"])
def list_topics(req: func.HttpRequest) -> func.HttpResponse:
    """List available Kafka topics."""
    logging.info("Listing topics.")
    topics = [
        {"name": "orders", "partitions": 6, "replication_factor": 3},
        {"name": "events", "partitions": 12, "replication_factor": 3},
    ]
    return func.HttpResponse(
        json.dumps({"topics": topics}),
        status_code=200,
        mimetype="application/json",
    )


@app.route("topics/{topic_name}/messages", methods=["POST"])
def produce_message(req: func.HttpRequest) -> func.HttpResponse:
    """Produce a message to a Kafka topic."""
    topic_name = req.route_params.get("topic_name")
    logging.info("Producing message to topic: %s", topic_name)

    try:
        body = req.get_json()
    except ValueError:
        return func.HttpResponse(
            json.dumps({"error": "Request body must be valid JSON."}),
            status_code=400,
            mimetype="application/json",
        )

    if "value" not in body:
        return func.HttpResponse(
            json.dumps({"error": "Missing required field: value"}),
            status_code=400,
            mimetype="application/json",
        )

    # Placeholder: integrate with confluent-kafka producer
    result = {
        "topic": topic_name,
        "key": body.get("key"),
        "value": body["value"],
        "status": "produced",
    }

    return func.HttpResponse(
        json.dumps(result),
        status_code=201,
        mimetype="application/json",
    )
