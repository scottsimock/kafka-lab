"""Azure Function App - Getting Started
Basic HTTP-triggered function using the Python v2 programming model.
"""

import azure.functions as func
import json
import logging

app = func.FunctionApp()


@app.route("health", methods=["GET"])
def health_check(req: func.HttpRequest) -> func.HttpResponse:
    """Health check endpoint."""
    return func.HttpResponse(
        json.dumps({"status": "healthy"}),
        status_code=200,
        mimetype="application/json",
    )


@app.route("hello", methods=["GET", "POST"])
def hello(req: func.HttpRequest) -> func.HttpResponse:
    """Simple greeting function with query parameter or JSON body support."""
    logging.info("Processing hello request.")

    name = req.params.get("name")
    if not name:
        try:
            req_body = req.get_json()
            name = req_body.get("name")
        except ValueError:
            pass

    if name:
        return func.HttpResponse(
            json.dumps({"message": f"Hello, {name}!"}),
            status_code=200,
            mimetype="application/json",
        )

    return func.HttpResponse(
        json.dumps({"error": "Pass a name in the query string or request body."}),
        status_code=400,
        mimetype="application/json",
    )
