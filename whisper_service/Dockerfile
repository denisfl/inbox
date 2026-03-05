# Use Debian Bookworm for better ARM64 package support
FROM python:3.12-bookworm

# Install minimal dependencies (only curl and ffmpeg for audio conversion)
RUN apt-get update && \
    DEBIAN_FRONTEND=noninteractive apt-get install -y --no-install-recommends \
    curl \
    xz-utils \
    && apt-get clean \
    && rm -rf /var/lib/apt/lists/*

# Download and install static FFmpeg binary from John Van Sickle's repository
# This bypasses the corrupted Debian ARM64 multimedia package mirrors
RUN curl -L https://johnvansickle.com/ffmpeg/releases/ffmpeg-release-arm64-static.tar.xz -o /tmp/ffmpeg.tar.xz && \
    tar -xJf /tmp/ffmpeg.tar.xz -C /tmp && \
    cp /tmp/ffmpeg-*-arm64-static/ffmpeg /usr/local/bin/ && \
    cp /tmp/ffmpeg-*-arm64-static/ffprobe /usr/local/bin/ && \
    chmod +x /usr/local/bin/ffmpeg /usr/local/bin/ffprobe && \
    rm -rf /tmp/ffmpeg*

# Upgrade pip and install setuptools
RUN pip install --no-cache-dir --upgrade pip setuptools wheel

# Install onnx-asr with CPU support for Parakeet v3 transcription
# onnx-asr uses ONNX Runtime for fast CPU inference (~18x real-time)
# Includes auto-punctuation and capitalization
RUN pip install --no-cache-dir "onnx-asr[cpu,hub]" flask gunicorn requests

# Create app directory
WORKDIR /app

# Copy application code
COPY app.py /app/

# Expose port
EXPOSE 5000

# Run with gunicorn for better performance
CMD ["gunicorn", "--bind", "0.0.0.0:5000", "--workers", "1", "--timeout", "600", "app:app"]
