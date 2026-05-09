# Sentiment Analyzer Flutter App

A simple Flutter application that uses Hugging Face AI to analyze text sentiment.

## Setup

1. Get a free Hugging Face API token from https://huggingface.co/settings/tokens
2. Open `lib/main.dart` and replace `YOUR_HUGGING_FACE_TOKEN` with your actual token
3. Run the app:
   ```bash
   flutter run -d linux   # Linux
   flutter run -d chrome  # Web
   flutter run -d android # Android (requires emulator or device)
   ```

## Features

- Enter any text in the input field
- Tap "Analyze Sentiment"
- Get instant results: POSITIVE or NEGATIVE with confidence score
- Uses `distilbert-base-uncased-finetuned-sst-2-english` model from Hugging Face

## Dependencies

- `http: ^1.0.0` for API calls
- Hugging Face Inference API (free tier)
