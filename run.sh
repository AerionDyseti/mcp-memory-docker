#!/bin/bash

# MCP Memory Service - Docker Management Script
# Easily manage the Docker container

set -e

CONTAINER_NAME="mcp-memory-service"

# Load configuration
CONFIG_FILE="config.sh"
if [ -f "$CONFIG_FILE" ]; then
    source "$CONFIG_FILE"
    export MCP_DATA_DIR
fi

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Helper functions
error() {
    echo -e "${RED}❌ Error: $1${NC}" >&2
}

success() {
    echo -e "${GREEN}✅ $1${NC}"
}

info() {
    echo -e "${BLUE}ℹ️  $1${NC}"
}

warning() {
    echo -e "${YELLOW}⚠️  $1${NC}"
}

check_docker() {
    if ! command -v docker &> /dev/null; then
        error "Docker is not installed"
        exit 1
    fi

    if ! docker info &> /dev/null; then
        error "Docker is not running. Please start Docker Desktop."
        exit 1
    fi
}

check_image() {
    if ! docker images | grep -q "memory-docker"; then
        warning "Docker image not found. Build it first with: ./build.sh"
        exit 1
    fi
}

show_usage() {
    cat << EOF
MCP Memory Service - Docker Management

Usage: ./run.sh [COMMAND]

Commands:
  start       Start the service (detached mode)
  stop        Stop the service
  restart     Restart the service
  status      Show service status
  logs        View logs (follow mode)
  logs-tail   View last 100 lines of logs
  health      Check service health
  shell       Open shell in container
  ps          Show container processes
  stats       Show resource usage
  version     Show repository version and manifest
  cleanup     Remove container and volumes (DELETES DATA!)
  help        Show this help message

Examples:
  ./run.sh start          # Start the service
  ./run.sh logs           # View logs
  ./run.sh health         # Check if service is healthy
  ./run.sh restart        # Restart the service

Service Access:
  - Dashboard:  http://localhost:8000/
  - MCP API:    http://localhost:8000/mcp
  - API Docs:   http://localhost:8000/api/docs
  - Health:     http://localhost:8000/api/health
EOF
}

cmd_start() {
    check_docker
    check_image

    if docker ps | grep -q "$CONTAINER_NAME"; then
        warning "Service is already running"
        cmd_status
        exit 0
    fi

    info "Starting MCP Memory Service..."
    docker-compose up -d

    echo ""
    success "Service started successfully!"
    echo ""
    info "Waiting for service to be ready..."
    sleep 3

    if curl -sf http://localhost:8000/api/health > /dev/null 2>&1; then
        success "Service is healthy!"
        echo ""
        echo "Access Points:"
        echo "  - Dashboard:  http://localhost:8000/"
        echo "  - MCP API:    http://localhost:8000/mcp"
        echo "  - API Docs:   http://localhost:8000/api/docs"
        echo ""
        echo "View logs: ./run.sh logs"
    else
        warning "Service started but health check failed"
        echo "Check logs: ./run.sh logs"
    fi
}

cmd_stop() {
    check_docker

    if ! docker ps | grep -q "$CONTAINER_NAME"; then
        warning "Service is not running"
        exit 0
    fi

    info "Stopping MCP Memory Service..."
    docker-compose stop

    success "Service stopped"
}

cmd_restart() {
    check_docker
    check_image

    info "Restarting MCP Memory Service..."
    docker-compose restart

    echo ""
    success "Service restarted"
    echo ""
    info "Waiting for service to be ready..."
    sleep 3

    if curl -sf http://localhost:8000/api/health > /dev/null 2>&1; then
        success "Service is healthy!"
    else
        warning "Health check failed after restart"
        echo "Check logs: ./run.sh logs"
    fi
}

cmd_status() {
    check_docker

    echo "=========================================="
    echo "MCP Memory Service - Status"
    echo "=========================================="
    echo ""

    if docker ps | grep -q "$CONTAINER_NAME"; then
        success "Container is running"

        # Get container info
        UPTIME=$(docker ps --filter "name=$CONTAINER_NAME" --format "{{.Status}}")
        echo "  Uptime: $UPTIME"

        # Check health
        if curl -sf http://localhost:8000/api/health > /dev/null 2>&1; then
            success "Service is healthy"

            # Get detailed health info
            HEALTH_INFO=$(curl -s http://localhost:8000/api/health 2>/dev/null)
            if [ -n "$HEALTH_INFO" ]; then
                echo ""
                echo "Health Details:"
                echo "$HEALTH_INFO" | python3 -m json.tool 2>/dev/null || echo "$HEALTH_INFO"
            fi
        else
            error "Service health check failed"
        fi

        echo ""
        echo "Resource Usage:"
        docker stats --no-stream --format "  CPU: {{.CPUPerc}}  Memory: {{.MemUsage}}" "$CONTAINER_NAME"

        echo ""
        echo "Access Points:"
        echo "  - Dashboard:  http://localhost:8000/"
        echo "  - MCP API:    http://localhost:8000/mcp"
        echo "  - Health:     http://localhost:8000/api/health"

    else
        warning "Container is not running"
        echo ""
        echo "Start the service with: ./run.sh start"
    fi
}

cmd_logs() {
    check_docker

    if ! docker ps | grep -q "$CONTAINER_NAME"; then
        error "Service is not running"
        exit 1
    fi

    info "Showing logs (Ctrl+C to exit)..."
    echo ""
    docker-compose logs -f
}

cmd_logs_tail() {
    check_docker

    if ! docker ps -a | grep -q "$CONTAINER_NAME"; then
        error "Container not found"
        exit 1
    fi

    info "Last 100 lines of logs:"
    echo ""
    docker-compose logs --tail=100
}

cmd_health() {
    check_docker

    echo "=========================================="
    echo "Health Check"
    echo "=========================================="
    echo ""

    if ! docker ps | grep -q "$CONTAINER_NAME"; then
        error "Container is not running"
        exit 1
    fi

    if curl -sf http://localhost:8000/api/health > /dev/null; then
        success "Service is healthy"
        echo ""
        curl -s http://localhost:8000/api/health | python3 -m json.tool 2>/dev/null
    else
        error "Health check failed"
        exit 1
    fi
}

cmd_shell() {
    check_docker

    if ! docker ps | grep -q "$CONTAINER_NAME"; then
        error "Service is not running"
        exit 1
    fi

    info "Opening shell in container (type 'exit' to leave)..."
    docker exec -it "$CONTAINER_NAME" /bin/bash
}

cmd_ps() {
    check_docker

    if ! docker ps | grep -q "$CONTAINER_NAME"; then
        error "Service is not running"
        exit 1
    fi

    docker-compose ps
}

cmd_stats() {
    check_docker

    if ! docker ps | grep -q "$CONTAINER_NAME"; then
        error "Service is not running"
        exit 1
    fi

    info "Resource usage (Ctrl+C to exit)..."
    echo ""
    docker stats "$CONTAINER_NAME"
}

cmd_version() {
    echo "=========================================="
    echo "Repository Version & Manifest"
    echo "=========================================="
    echo ""

    MANIFEST_FILE="manifest.json"
    if [ -f "$MANIFEST_FILE" ]; then
        if command -v python3 &> /dev/null; then
            python3 -m json.tool "$MANIFEST_FILE" 2>/dev/null || cat "$MANIFEST_FILE"
        else
            cat "$MANIFEST_FILE"
        fi
    else
        error "Manifest file not found"
        echo ""
        info "Run ./build.sh to generate the manifest"
        exit 1
    fi
}

cmd_cleanup() {
    check_docker

    warning "This will remove the container and all data (database will be deleted)!"
    read -p "Are you sure? (type 'yes' to confirm): " -r
    echo ""

    if [[ "$REPLY" != "yes" ]]; then
        info "Cleanup cancelled"
        exit 0
    fi

    info "Stopping and removing container..."
    docker-compose down -v

    success "Cleanup complete"
    echo ""
    info "To start fresh, run: ./build.sh && ./run.sh start"
}

# Main command handler
COMMAND="${1:-help}"

case "$COMMAND" in
    start)
        cmd_start
        ;;
    stop)
        cmd_stop
        ;;
    restart)
        cmd_restart
        ;;
    status)
        cmd_status
        ;;
    logs)
        cmd_logs
        ;;
    logs-tail)
        cmd_logs_tail
        ;;
    health)
        cmd_health
        ;;
    shell)
        cmd_shell
        ;;
    ps)
        cmd_ps
        ;;
    stats)
        cmd_stats
        ;;
    version)
        cmd_version
        ;;
    cleanup)
        cmd_cleanup
        ;;
    help|--help|-h)
        show_usage
        ;;
    *)
        error "Unknown command: $COMMAND"
        echo ""
        show_usage
        exit 1
        ;;
esac
