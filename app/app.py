"""
Minimal Flask service used to demonstrate the CI/CD pipeline.
Exposes a health endpoint (used by the ALB target group) and a
version endpoint (used to visually confirm blue/green deployments).
"""
import os
import socket
from datetime import datetime, timezone

from flask import Flask, jsonify

app = Flask(__name__)

APP_VERSION = os.environ.get("APP_VERSION", "dev-local")
DEPLOY_COLOR = os.environ.get("DEPLOY_COLOR", "unset")  # "blue" or "green"


@app.get("/")
def index():
    return jsonify(
        {
            "service": "aws-cicd-ecs-demo",
            "message": "Hello from ECS Fargate",
            "version": APP_VERSION,
            "deploy_color": DEPLOY_COLOR,
            "hostname": socket.gethostname(),
            "timestamp": datetime.now(timezone.utc).isoformat(),
        }
    )


@app.get("/health")
def health():
    # Used by the ALB target group health check (see terraform/modules/alb)
    return jsonify({"status": "healthy"}), 200


@app.get("/version")
def version():
    return jsonify({"version": APP_VERSION, "deploy_color": DEPLOY_COLOR})


if __name__ == "__main__":
    app.run(host="0.0.0.0", port=int(os.environ.get("PORT", 8080)))
