"""
Sentiment Analysis API using HuggingFace
Runs on localhost:5000
"""
from flask import Flask, request, jsonify
from transformers import pipeline

app = Flask(__name__)

# Load the sentiment analysis model (downloads on first run ~270MB)
print("Loading sentiment model... (this may take a minute on first run)")
sentiment_pipeline = pipeline(
    "sentiment-analysis",
    model="distilbert-base-uncased-finetuned-sst-2-english"
)

@app.route('/analyze', methods=['POST'])
def analyze_sentiment():
    """
    Analyze sentiment of provided text
    Expected JSON: {"text": "your mood note here"}
    Returns: {"score": 0.0-1.0, "label": "POSITIVE/NEGATIVE"}
    """
    data = request.get_json()
    text = data.get('text', '')
    
    if not text:
        return jsonify({"error": "No text provided"}), 400
    
    try:
        # Run sentiment analysis
        result = sentiment_pipeline(text)[0]
        label = result['label']  # "POSITIVE" or "NEGATIVE"
        confidence = result['score']  # 0.0-1.0
        
        # Convert to mood score: POSITIVE → higher, NEGATIVE → lower
        if label == 'POSITIVE':
            mood_score = confidence  # 0.5-1.0
        else:
            mood_score = 1.0 - confidence  # 0.0-0.5
        
        return jsonify({
            "score": round(mood_score, 3),
            "label": label,
            "confidence": round(confidence, 3)
        })
    
    except Exception as e:
        return jsonify({"error": str(e)}), 500

@app.route('/health', methods=['GET'])
def health_check():
    """Health check endpoint"""
    return jsonify({"status": "ok"})

if __name__ == '__main__':
    print("🚀 Sentiment Analysis API running on http://localhost:5000")
    print("📝 POST to /analyze with JSON: {\"text\": \"your mood here\"}")
    app.run(debug=True, port=5000, host='0.0.0.0')
