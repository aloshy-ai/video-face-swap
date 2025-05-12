#!/bin/bash
# Startup script for Video Face Swap API

# Set default port if not set
export PORT=${PORT:-8080}

# Create necessary directories
mkdir -p /app/.models /app/.cache /app/.insightface

# Start gunicorn
exec gunicorn --bind 0.0.0.0:${PORT} --workers 1 --threads 8 api:app
