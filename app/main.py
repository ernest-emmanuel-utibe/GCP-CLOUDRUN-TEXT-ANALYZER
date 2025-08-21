from fastapi import FastAPI, HTTPException
from pydantic import BaseModel
from datetime import datetime
import os
import logging

# Configure logging
logging.basicConfig(level=logging.INFO)
logger = logging.getLogger(__name__)

app = FastAPI(
    title="Text Analyzer API",
    description="A simple text analysis service that counts words and characters",
    version="1.0.0"
)

class TextRequest(BaseModel):
    text: str

class TextResponse(BaseModel):
    original_text: str
    word_count: int
    character_count: int
    analysis_timestamp: str

@app.get("/")
async def health_check():
    """Health check endpoint"""
    return {
        "status": "healthy",
        "service": "text-analyzer",
        "timestamp": datetime.utcnow().isoformat() + "Z"
    }

@app.get("/health")
async def health():
    """Kubernetes-style health check"""
    return {"status": "ok"}

@app.post("/analyze", response_model=TextResponse)
async def analyze_text(request: TextRequest):
    """
    Analyze text and return word count and character count
    
    Args:
        request: JSON body containing text to analyze
        
    Returns:
        JSON response with analysis results
    """
    try:
        logger.info(f"Analyzing text with length: {len(request.text)}")
        
        # Validate input
        if not request.text:
            raise HTTPException(status_code=400, detail="Text cannot be empty")
        
        if len(request.text) > 10000:  # Reasonable limit
            raise HTTPException(status_code=400, detail="Text too long (max 10,000 characters)")
        
        # Perform analysis
        word_count = len(request.text.split())
        character_count = len(request.text)
        
        # Create response
        response = TextResponse(
            original_text=request.text,
            word_count=word_count,
            character_count=character_count,
            analysis_timestamp=datetime.utcnow().isoformat() + "Z"
        )
        
        logger.info(f"Analysis complete: {word_count} words, {character_count} characters")
        return response
        
    except HTTPException:
        raise
    except Exception as e:
        logger.error(f"Unexpected error during text analysis: {str(e)}")
        raise HTTPException(status_code=500, detail="Internal server error")

if __name__ == "__main__":
    import uvicorn
    port = int(os.getenv("PORT", 8000))
    uvicorn.run(app, host="0.0.0.0", port=port)


# from flask import Flask, request, jsonify

# app = Flask(__name__)

# @app.route("/analyze", methods=["POST"])
# def analyze():
#     data = request.get_json(silent=True) or {}
#     text = data.get("text", "")
#     # Normalize newlines, no trimming to keep character_count intuitive.
#     word_count = len([w for w in text.split() if w])
#     character_count = len(text)
#     return jsonify({
#         "original_text": text,
#         "word_count": word_count,
#         "character_count": character_count
#     }), 200

# @app.route("/healthz", methods=["GET"])
# def health():
#     return "ok", 200

# if __name__ == "__main__":
#     # For local dev only. In Cloud Run we use gunicorn (see Dockerfile).
#     app.run(host="0.0.0.0", port=8080)
