import os
import logging
from flask import Flask, jsonify
from prometheus_flask_exporter import PrometheusMetrics

# --- Logging setup (structured JSON logs) ---
logging.basicConfig(
    level=logging.INFO,
    format='{"time":"%(asctime)s","level":"%(levelname)s","msg":"%(message)s"}'
)
logger = logging.getLogger(__name__)

# --- Create the Flask app ---
app = Flask(__name__)
metrics = PrometheusMetrics(app)  # Auto-exposes /metrics endpoint


# --- Routes ---
@app.route("/health")
def health():
    """Liveness probe — is the app alive?"""
    return jsonify({"status": "healthy", "service": "securecloud-flask"}), 200


@app.route("/ready")
def ready():
    """Readiness probe — is the app ready to take traffic?"""
    return jsonify({"status": "ready"}), 200


@app.route("/")
def index():
    logger.info("Root endpoint hit")
    return jsonify({"message": "SecureCloud-Flask is running!"}), 200


@app.route("/api/users", methods=["GET"])
def get_users():
    """Example API endpoint (later connects to MySQL)"""
    users = [
        {"id": 1, "name": "Alice"},
        {"id": 2, "name": "Bob"},
    ]
    return jsonify(users), 200


if __name__ == "__main__":
    port = int(os.environ.get("PORT", 5000))
    app.run(host="0.0.0.0", port=port)
