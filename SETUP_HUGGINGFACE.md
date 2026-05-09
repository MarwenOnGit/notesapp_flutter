# HuggingFace Sentiment Analysis Setup Guide

## Quick Start

### 1. Install Python Dependencies
```bash
pip install flask transformers torch
```

**Note:** First run will download the model (~270MB). This happens automatically.

### 2. Start the Sentiment API Server
```bash
# From the project root directory
python sentiment_api.py
```

You should see:
```
🚀 Sentiment Analysis API running on http://localhost:5000
📝 POST to /analyze with JSON: {"text": "your mood here"}
```

### 3. Test the API (Optional)
```bash
# In another terminal
curl -X POST http://localhost:5000/analyze \
  -H "Content-Type: application/json" \
  -d '{"text": "I am feeling great today!"}'

# You should get:
# {"score": 0.998, "label": "POSITIVE", "confidence": 0.998}
```

### 4. Run Your Flutter App
```bash
flutter run -d "127.0.0.1:6555"
```

**Important:** The Python API must be running BEFORE you use the app!

---

## How It Works

1. **You add a mood note** in the app
2. **App sends text** to `http://localhost:5000/analyze`
3. **Python API** uses HuggingFace model to classify sentiment
4. **Returns a score** (0.0 = negative/sad, 1.0 = positive/happy)
5. **App displays mood** with emoji (😞/😐/😊)

---

## Model Details

- **Model:** `distilbert-base-uncased-finetuned-sst-2-english`
- **Size:** ~270MB (auto-downloaded on first run)
- **Speed:** < 1 second per analysis
- **Accuracy:** ~95% for sentiment classification
- **Languages:** English only

---

## Troubleshooting

### Error: "Connection refused" or "No route to host"
- Make sure Python API is running on localhost:5000
- Check `python sentiment_api.py` output

### Error: "Module not found: transformers"
- Run: `pip install transformers`

### Slow first request (30+ seconds)
- Normal! The model is downloading/loading (~270MB)
- Subsequent requests are < 1 second

### Port 5000 already in use
- Find the process: `lsof -i :5000`
- Kill it: `kill -9 <PID>`
- Or change port in sentiment_api.py and main.dart

---

## Performance Notes

- ✅ Works completely offline (after model download)
- ✅ No API keys needed
- ✅ No internet required
- ✅ <1 second per analysis
- ✅ Free forever

---

## Future Improvements

- Add caching so repeated text isn't re-analyzed
- Support for emotion detection (joy, anger, etc.)
- Multiple language support
- Add confidence threshold

Enjoy your mood diary! 🎉
