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

# Maximum chunk duration in seconds (60 seconds).
# Audio longer than this is split into overlapping chunks before transcription.
# Short chunks improve RPi 5 memory usage and reduce per-chunk latency.
MAX_CHUNK_SECONDS = int(os.getenv("MAX_CHUNK_SECONDS", "60"))
# Overlap between chunks (seconds) to avoid cutting words at boundaries.
CHUNK_OVERLAP_SECONDS = int(os.getenv("CHUNK_OVERLAP_SECONDS", "2"))
# Maximum total audio duration in seconds (30 minutes).
# Files longer than this are rejected to avoid excessive resource usage.
MAX_AUDIO_DURATION_SECONDS = int(os.getenv("MAX_AUDIO_DURATION_SECONDS", "1800"))

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


def get_audio_duration(path):
    """Get audio duration in seconds using ffprobe."""
    try:
        result = subprocess.run(
            [
                "ffprobe", "-v", "error",
                "-show_entries", "format=duration",
                "-of", "default=noprint_wrappers=1:nokey=1",
                path
            ],
            capture_output=True, text=True, timeout=30
        )
        if result.returncode == 0 and result.stdout.strip():
            return float(result.stdout.strip())
    except (subprocess.TimeoutExpired, ValueError) as e:
        logger.warning(f"Could not determine audio duration: {e}")
    return None


def split_audio(wav_path, max_seconds, overlap_seconds):
    """Split a WAV file into chunks of max_seconds with overlap_seconds overlap.

    Returns a list of chunk file paths (caller must clean up).
    """
    duration = get_audio_duration(wav_path)
    if duration is None or duration <= max_seconds:
        return [wav_path]

    chunks = []
    start = 0.0
    idx = 0
    step = max_seconds - overlap_seconds

    while start < duration:
        chunk_path = f"{wav_path}.chunk{idx}.wav"
        end = min(start + max_seconds, duration)
        try:
            result = subprocess.run(
                [
                    "ffmpeg", "-y",
                    "-i", wav_path,
                    "-ss", str(start),
                    "-t", str(end - start),
                    "-ar", "16000", "-ac", "1", "-sample_fmt", "s16",
                    chunk_path
                ],
                capture_output=True, text=True, timeout=120
            )
            if result.returncode != 0:
                logger.error(f"ffmpeg chunk split failed: {result.stderr}")
                # Fall back to single-file transcription
                for c in chunks:
                    if os.path.exists(c):
                        os.unlink(c)
                return [wav_path]
            chunks.append(chunk_path)
        except subprocess.TimeoutExpired:
            logger.error("ffmpeg chunk split timed out")
            for c in chunks:
                if os.path.exists(c):
                    os.unlink(c)
            return [wav_path]

        start += step
        idx += 1

    logger.info(f"Split audio ({duration:.0f}s) into {len(chunks)} chunks of ~{max_seconds}s")
    return chunks


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

        # Check duration limit
        duration = get_audio_duration(wav_path)
        if duration is not None and duration > MAX_AUDIO_DURATION_SECONDS:
            os.unlink(tmp_path)
            if wav_path != tmp_path and os.path.exists(wav_path):
                os.unlink(wav_path)
            max_min = MAX_AUDIO_DURATION_SECONDS // 60
            actual_min = int(duration // 60)
            return jsonify({
                "error": f"Audio too long: {actual_min} min (max {max_min} min)"
            }), 413

        # Get model instance (lazy-loaded on first request)
        parakeet = get_model()

        start_time = time.time()

        # Split long audio into chunks to avoid OOM / 500 errors
        chunk_paths = split_audio(wav_path, MAX_CHUNK_SECONDS, CHUNK_OVERLAP_SECONDS)
        chunk_texts = []

        for i, chunk_path in enumerate(chunk_paths):
            logger.info(f"Transcribing chunk {i+1}/{len(chunk_paths)}: {chunk_path}")
            transcription = parakeet.recognize(chunk_path)

            # Handle result — onnx-asr returns a string directly
            if isinstance(transcription, str):
                chunk_text = transcription.strip()
            elif hasattr(transcription, "text"):
                chunk_text = transcription.text.strip()
            else:
                chunk_text = str(transcription).strip()

            if chunk_text:
                chunk_texts.append(chunk_text)

        text = " ".join(chunk_texts)

        elapsed = time.time() - start_time

        # Clean up temporary files
        os.unlink(tmp_path)
        if wav_path != tmp_path and os.path.exists(wav_path):
            os.unlink(wav_path)
        for cp in chunk_paths:
            if cp != wav_path and os.path.exists(cp):
                os.unlink(cp)

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
