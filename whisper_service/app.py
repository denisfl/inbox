"""
Parakeet v3 Transcription Service
Flask HTTP API for NVIDIA Parakeet TDT 0.6B v3 via onnx-asr
Optimized for Raspberry Pi 5 - uses CPU inference via ONNX Runtime
"""

from flask import Flask, request, jsonify
import onnx_asr
import os
import tempfile
import logging
import time
import subprocess

# Configure logging
logging.basicConfig(level=logging.INFO)
logger = logging.getLogger(__name__)

app = Flask(__name__)

# Model configuration
MODEL_NAME = os.getenv("PARAKEET_MODEL", "nemo-parakeet-tdt-0.6b-v3")

# Lazy-load model to avoid blocking gunicorn worker initialization
model = None


def get_model():
    """Lazy-load the Parakeet model on first request"""
    global model
    if model is None:
        logger.info(f"Loading onnx-asr model: {MODEL_NAME}")
        model = onnx_asr.load_model(MODEL_NAME)
        logger.info("onnx-asr model loaded successfully")
    return model


def convert_to_wav(input_path):
    """Convert any audio format to 16kHz mono WAV using ffmpeg.

    Parakeet/onnx-asr requires WAV (RIFF) format.
    Browser MediaRecorder produces WebM (Opus), Telegram sends OGG (Opus).
    """
    wav_path = input_path + ".wav"
    try:
        result = subprocess.run(
            [
                "ffmpeg", "-y",
                "-i", input_path,
                "-ar", "16000",     # 16kHz sample rate (required by Parakeet)
                "-ac", "1",         # mono
                "-sample_fmt", "s16",  # 16-bit PCM
                wav_path
            ],
            capture_output=True,
            text=True,
            timeout=120
        )
        if result.returncode != 0:
            logger.error(f"ffmpeg conversion failed: {result.stderr}")
            raise RuntimeError(f"ffmpeg failed: {result.stderr[:500]}")
        logger.info(f"Converted audio to WAV: {wav_path}")
        return wav_path
    except subprocess.TimeoutExpired:
        raise RuntimeError("ffmpeg conversion timed out")


@app.route("/health", methods=["GET"])
def health():
    """Health check endpoint"""
    return jsonify({
        "status": "ok",
        "model": MODEL_NAME,
        "engine": "onnx-asr"
    }), 200


@app.route("/transcribe", methods=["POST"])
def transcribe():
    """
    Transcribe audio file using Parakeet v3

    Form parameters:
    - audio: Audio file (required)
    - language: Language code, e.g. 'ru', 'en' (optional, informational only - Parakeet auto-detects)

    Returns:
    - text: Full transcription (with punctuation and capitalization)
    - language: Requested language (Parakeet auto-detects internally)
    - segments: Empty list (onnx-asr returns full text, not segments)
    """
    try:
        # Validate request
        if "audio" not in request.files:
            return jsonify({"error": "No audio file provided"}), 400

        audio_file = request.files["audio"]

        if audio_file.filename == "":
            return jsonify({"error": "Empty filename"}), 400

        # Get optional language parameter (informational - Parakeet auto-detects)
        language = request.form.get("language", None)

        # Save uploaded file temporarily
        with tempfile.NamedTemporaryFile(delete=False, suffix=".audio") as tmp_file:
            audio_file.save(tmp_file.name)
            tmp_path = tmp_file.name

        logger.info(f"Transcribing file: {audio_file.filename}, language hint: {language or 'auto'}")

        # Convert to WAV format (Parakeet/onnx-asr requires RIFF/WAV)
        # Browser records WebM/Opus, Telegram sends OGG/Opus
        wav_path = convert_to_wav(tmp_path)

        # Get model instance (lazy-loaded on first request)
        parakeet = get_model()

        start_time = time.time()

        # Transcribe with Parakeet v3
        # Returns text with automatic punctuation and capitalization
        transcription = parakeet.recognize(wav_path)

        elapsed = time.time() - start_time

        # Clean up temporary files
        os.unlink(tmp_path)
        os.unlink(wav_path)

        # Handle result — onnx-asr returns a string directly
        if isinstance(transcription, str):
            text = transcription.strip()
        elif hasattr(transcription, "text"):
            text = transcription.text.strip()
        else:
            text = str(transcription).strip()

        logger.info(f"Transcription complete in {elapsed:.1f}s: {len(text)} chars")

        # Return results (compatible with existing TranscribeAudioJob API)
        return jsonify({
            "text": text,
            "language": language or "auto",
            "language_probability": 1.0,
            "segments": []
        }), 200

    except Exception as e:
        logger.error(f"Transcription error: {str(e)}")
        return jsonify({"error": str(e)}), 500


if __name__ == "__main__":
    # Development server (use gunicorn in production)
    app.run(host="0.0.0.0", port=5000, debug=False)
