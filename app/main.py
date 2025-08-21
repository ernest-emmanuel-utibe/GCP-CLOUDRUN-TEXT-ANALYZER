from flask import Flask, request, jsonify

app = Flask(__name__)

@app.route("/analyze", methods=["POST"])
def analyze():
    data = request.get_json(silent=True) or {}
    text = data.get("text", "")
    # Normalize newlines, no trimming to keep character_count intuitive.
    word_count = len([w for w in text.split() if w])
    character_count = len(text)
    return jsonify({
        "original_text": text,
        "word_count": word_count,
        "character_count": character_count
    }), 200

@app.route("/healthz", methods=["GET"])
def health():
    return "ok", 200

if __name__ == "__main__":
    # For local dev only. In Cloud Run we use gunicorn (see Dockerfile).
    app.run(host="0.0.0.0", port=8080)
