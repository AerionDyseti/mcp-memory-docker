# Truly Fixed Dockerfile for MCP Memory Service with sqlite-vec compiled from source
FROM --platform=linux/arm64 python:3.12-slim AS base

# Build arguments
ARG DEBIAN_FRONTEND=noninteractive

# Environment variables
ENV PYTHONUNBUFFERED=1 \
    PYTHONDONTWRITEBYTECODE=1 \
    PIP_NO_CACHE_DIR=1 \
    PIP_DISABLE_PIP_VERSION_CHECK=1 \
    MCP_MEMORY_STORAGE_BACKEND=sqlite_vec \
    MCP_MEMORY_SQLITE_PATH=/app/data/sqlite_vec.db \
    MCP_MEMORY_BACKUPS_PATH=/app/data/backups \
    MCP_HTTP_ENABLED=true \
    MCP_HTTP_PORT=8000 \
    MCP_HTTP_HOST=0.0.0.0 \
    PYTHONPATH=/app/src \
    HF_HOME=/root/.cache/huggingface \
    TRANSFORMERS_CACHE=/root/.cache/huggingface/transformers \
    HF_HUB_DISABLE_TELEMETRY=1 \
    DOCKER_CONTAINER=1

WORKDIR /app

# Install system dependencies including build tools for compiling sqlite-vec
RUN apt-get update && \
    apt-get install -y --no-install-recommends \
        curl \
        ca-certificates \
        git \
        build-essential \
        gcc \
        g++ \
        make \
        sqlite3 \
        libsqlite3-dev \
        gettext-base \
        && apt-get upgrade -y \
        && rm -rf /var/lib/apt/lists/* \
        && apt-get clean

# Build sqlite-vec from source for ARM64
RUN echo "Building sqlite-vec from source for ARM64..." && \
    git clone https://github.com/asg017/sqlite-vec.git /tmp/sqlite-vec && \
    cd /tmp/sqlite-vec && \
    make loadable && \
    mkdir -p /usr/local/lib/sqlite-vec && \
    cp dist/vec0.so /usr/local/lib/sqlite-vec/ && \
    echo "Testing compiled extension..." && \
    sqlite3 :memory: ".load /usr/local/lib/sqlite-vec/vec0.so" "SELECT vec_version();" && \
    rm -rf /tmp/sqlite-vec && \
    echo "sqlite-vec built successfully!"

# Copy project files
COPY mcp-memory-service/pyproject.toml mcp-memory-service/uv.lock mcp-memory-service/README.md ./
COPY mcp-memory-service/scripts/installation/install_uv.py ./

# Install UV package manager
RUN python install_uv.py && \
    rm install_uv.py

# Copy source code
COPY mcp-memory-service/src/ ./src/
COPY mcp-memory-service/run_server.py ./

# CRITICAL FIX: Create a dummy sqlite-vec package BEFORE installing dependencies
# This satisfies the dependency requirement without installing the broken PyPI version
RUN mkdir -p /usr/local/lib/python3.12/site-packages/sqlite_vec && \
    mkdir -p /usr/local/lib/python3.12/site-packages/sqlite_vec-0.1.6.dist-info && \
    echo 'import os\n\
import sqlite3\n\
\n\
def loadable_path():\n\
    return "/usr/local/lib/sqlite-vec/vec0.so"\n\
\n\
def load(conn):\n\
    """Load the sqlite-vec extension into the given connection."""\n\
    conn.enable_load_extension(True)\n\
    conn.load_extension(loadable_path())\n\
    conn.enable_load_extension(False)\n\
\n\
def serialize_float32(values):\n\
    """Serialize a list of floats to bytes for storage."""\n\
    import struct\n\
    return struct.pack(f"{len(values)}f", *values)\n\
\n\
__version__ = "0.1.6"' > /usr/local/lib/python3.12/site-packages/sqlite_vec/__init__.py && \
    echo 'Metadata-Version: 2.1\n\
Name: sqlite-vec\n\
Version: 0.1.6\n\
Summary: Custom compiled sqlite-vec for ARM64\n\
' > /usr/local/lib/python3.12/site-packages/sqlite_vec-0.1.6.dist-info/METADATA && \
    echo 'sqlite_vec' > /usr/local/lib/python3.12/site-packages/sqlite_vec-0.1.6.dist-info/top_level.txt && \
    echo 'sqlite_vec/__init__.py' > /usr/local/lib/python3.12/site-packages/sqlite_vec-0.1.6.dist-info/RECORD

# Now install dependencies - UV will see sqlite-vec is already installed and skip it
RUN echo "Installing CPU-only PyTorch..." && \
    python -m uv pip install torch --index-url https://download.pytorch.org/whl/cpu && \
    echo "Installing ONNX Runtime for quantized model support..." && \
    python -m uv pip install onnxruntime && \
    echo "Installing MCP Memory Service (sqlite-vec already satisfied)..." && \
    python -m uv pip install -e . && \
    echo "Installation complete"

# Verify our custom sqlite-vec is still in place and working
RUN python -c "import sqlite_vec; print(f'sqlite-vec version: {sqlite_vec.__version__}'); print(f'Extension path: {sqlite_vec.loadable_path()}')" && \
    python -c "import sqlite3; import sqlite_vec; conn = sqlite3.connect(':memory:'); sqlite_vec.load(conn); print('SUCCESS: Custom sqlite-vec is working!')"

# Pre-download embedding model during build (baked into image)
RUN echo "Downloading embedding model (all-MiniLM-L6-v2)..." && \
    python -c "from sentence_transformers import SentenceTransformer; \
    import sys; \
    print('Initializing SentenceTransformer...', file=sys.stderr); \
    model = SentenceTransformer('all-MiniLM-L6-v2'); \
    print('Model downloaded and cached successfully!', file=sys.stderr); \
    test_embedding = model.encode(['test']); \
    print(f'Test embedding shape: {test_embedding.shape}', file=sys.stderr)" && \
    echo "Embedding model ready"

# Create data directories
RUN mkdir -p /app/data /app/data/backups && \
    chmod 755 /app/data /app/data/backups

# Copy entrypoint script
COPY docker-entrypoint.sh /usr/local/bin/
RUN chmod +x /usr/local/bin/docker-entrypoint.sh

# Health check
HEALTHCHECK --interval=30s --timeout=10s --start-period=10s --retries=3 \
    CMD curl -f http://localhost:8000/api/health || exit 1

# Expose port
EXPOSE 8000

# Volume for persistent data
VOLUME ["/app/data"]

# Entrypoint
ENTRYPOINT ["/usr/local/bin/docker-entrypoint.sh"]