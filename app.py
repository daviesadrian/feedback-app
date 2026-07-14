import os

from flask import Flask, request, jsonify
from google.cloud import firestore

app = Flask(__name__)

PROJECT_ID = os.environ.get("GOOGLE_CLOUD_PROJECT", "cloud-portfolio-789")
db = firestore.Client(project=PROJECT_ID)
feedback_collection = db.collection("feedback")


@app.route("/feedback", methods=["POST"])
def submit_feedback():
    data = request.get_json(silent=True) or {}
    name = data.get("name")
    message = data.get("message")

    if not name or not message:
        return jsonify({"error": "name and message are required"}), 400

    doc_ref = feedback_collection.document()
    entry = {"name": name, "message": message}
    doc_ref.set(entry)
    return jsonify({"id": doc_ref.id, **entry}), 201


@app.route("/feedback", methods=["GET"])
def list_feedback():
    docs = feedback_collection.stream()
    results = [{"id": doc.id, **doc.to_dict()} for doc in docs]
    return jsonify(results)


@app.route("/", methods=["GET"])
def health():
    return jsonify({"status": "ok"})


if __name__ == "__main__":
    app.run(host="0.0.0.0", port=8080, debug=True)
