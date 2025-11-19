#!/bin/bash
set -e

# MCP Memory Service Docker Entrypoint
# HTTP-only mode with SQLite-vec backend

echo "=========================================="
echo "MCP Memory Service - HTTP Mode"
echo "=========================================="

# Display configuration
echo "Configuration:"
echo "  Storage Backend: ${MCP_MEMORY_STORAGE_BACKEND:-sqlite_vec}"
echo "  Database Path: ${MCP_MEMORY_SQLITE_PATH:-/app/data/sqlite_vec.db}"
echo "  HTTP Port: ${MCP_HTTP_PORT:-8000}"
echo "  HTTP Host: ${MCP_HTTP_HOST:-0.0.0.0}"
echo "  Log Level: ${LOG_LEVEL:-INFO}"
echo ""

# Ensure data directory exists
DATA_DIR="/app/data"
if [ ! -d "$DATA_DIR" ]; then
    echo "Creating data directory: $DATA_DIR"
    mkdir -p "$DATA_DIR"
fi

# Ensure backups directory exists
BACKUPS_DIR="${MCP_MEMORY_BACKUPS_PATH:-/app/data/backups}"
if [ ! -d "$BACKUPS_DIR" ]; then
    echo "Creating backups directory: $BACKUPS_DIR"
    mkdir -p "$BACKUPS_DIR"
fi

# Set proper permissions
chmod 755 "$DATA_DIR" 2>/dev/null || true
chmod 755 "$BACKUPS_DIR" 2>/dev/null || true

# Display storage info
DB_PATH="${MCP_MEMORY_SQLITE_PATH:-/app/data/sqlite_vec.db}"
if [ -f "$DB_PATH" ]; then
    DB_SIZE=$(du -h "$DB_PATH" | cut -f1)
    echo "Database Status: Existing database found (Size: $DB_SIZE)"
else
    echo "Database Status: Will be created on first use"
fi

echo ""
echo "=========================================="
echo "Starting HTTP Server..."
echo "=========================================="
echo ""
echo "Access Points:"
echo "  - Dashboard: http://localhost:${MCP_HTTP_PORT:-8000}/"
echo "  - MCP Endpoint: http://localhost:${MCP_HTTP_PORT:-8000}/mcp"
echo "  - API Docs: http://localhost:${MCP_HTTP_PORT:-8000}/api/docs"
echo "  - Health: http://localhost:${MCP_HTTP_PORT:-8000}/api/health"
echo ""
echo "Claude Code Configuration:"
echo '  {
    "mcpServers": {
      "memory": {
        "type": "http",
        "url": "http://localhost:'${MCP_HTTP_PORT:-8000}'/mcp"
      }
    }
  }'
echo ""
echo "=========================================="
echo ""

# Trap signals for graceful shutdown
trap 'echo "Shutting down..."; exit 0' SIGTERM SIGINT

# Start the HTTP server
exec python run_server.py
