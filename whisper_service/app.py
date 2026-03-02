"""
Whisper Transcription Service
Flask HTTP API for faster-whisper audio transcription
Optimized for Raspberry Pi 5 - uses CPU inference with INT8 quantization
"""

from flask import Flask, request, jsonify
from faster_whisper import WhisperModel
import os
import tempfile
import logging

# Configure logging
logging.basicConfig(level=logging.INFO)
logger = logging.getLogger(__name__)

app = Flask(__name__)

# Model configuration
MODEL_SIZE = os.getenv('WHISPER_MODEL_SIZE', 'base')
DEVICE = os.getenv('WHISPER_DEVICE', 'cpu')  # cpu or cuda
COMPUTE_TYPE = os.getenv('WHISPER_COMPUTE_TYPE', 'int8')  # int8 for CPU, float16 for GPU

# Lazy-load model to avoid blocking gunicorn worker initialization
model = None

def get_model():
    """Lazy-load the Whisper model on first request"""
    global model
    if model is None:
        logger.info(f"Loading faster-whisper model: {MODEL_SIZE} on {DEVICE} with {COMPUTE_TYPE}")
        model = WhisperModel(MODEL_SIZE, device=DEVICE, compute_type=COMPUTE_TYPE)
        logger.info("faster-whisper model loaded successfully")
    return model


@app.route('/health', methods=['GET'])
def health():
    """Health check endpoint"""
    return jsonify({
        'status': 'ok', 
        'model': MODEL_SIZE,
        'device': DEVICE,
        'compute_type': COMPUTE_TYPE
    }), 200


@app.route('/transcribe', methods=['POST'])
def transcribe():
    """
    Transcribe audio file
    
    Form parameters:
    - audio: Audio file (required)
    - language: Language code, e.g. 'ru', 'en' (optional, default: auto-detect)
    
    Returns:
    - text: Full transcription
    - segments: Timestamped segments with word-level timestamps
    - language: Detected language
    """
    try:
        # Validate request
        if 'audio' not in request.files:
            return jsonify({'error': 'No audio file provided'}), 400
        
        audio_file = request.files['audio']
        
        if audio_file.filename == '':
            return jsonify({'error': 'Empty filename'}), 400
        
        # Get optional language parameter
        language = request.form.get('language', None)
        
        # Save uploaded file temporarily
        with tempfile.NamedTemporaryFile(delete=False, suffix='.audio') as tmp_file:
            audio_file.save(tmp_file.name)
            tmp_path = tmp_file.name
        
        logger.info(f"Transcribing file: {audio_file.filename}, language: {language or 'auto'}")
        
        # Get model instance (lazy-loaded on first request)
        whisper_model = get_model()
        
        # Transcribe with faster-whisper
        # beam_size=5 improves accuracy and reduces hallucinations
        segments, info = whisper_model.transcribe(
            tmp_path,
            language=language,
            beam_size=5,
            vad_filter=True,  # Voice Activity Detection - reduces hallucinations during silence
            word_timestamps=False  # Set to True if you need word-level timestamps
        )
        
        # Clean up temporary file
        os.unlink(tmp_path)
        
        # Extract results
        segments_list = []
        transcription_parts = []
        
        for segment in segments:
            segments_list.append({
                'start': segment.start,
                'end': segment.end,
                'text': segment.text
            })
            transcription_parts.append(segment.text)
        
        transcription = ' '.join(transcription_parts).strip()
        detected_language = info.language
        
        logger.info(f"Transcription complete: {len(transcription)} chars, language: {detected_language}")
        
        # Return results
        return jsonify({
            'text': transcription,
            'language': detected_language,
            'language_probability': info.language_probability,
            'segments': segments_list
        }), 200
        
    except Exception as e:
        logger.error(f"Transcription error: {str(e)}")
        return jsonify({'error': str(e)}), 500


if __name__ == '__main__':
    # Development server (use gunicorn in production)
    app.run(host='0.0.0.0', port=5000, debug=False)
