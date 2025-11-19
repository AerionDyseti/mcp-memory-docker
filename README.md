# MCP Memory Service - Self-Contained Docker Deployment

A complete, self-contained Docker deployment tool for running [doobidoo's MCP Memory Service](https://github.com/doobidoo/mcp-memory-service) with a single command. Designed for easy integration with Claude Code.

## What This Tool Does

This tool provides a zero-configuration way to run the MCP Memory Service in Docker:

- **Automatic Repository Cloning** - Downloads the latest version of mcp-memory-service
- **Version Tracking** - Generates a manifest to track which version you're running
- **Configurable Storage** - Choose where your SQLite database is stored
- **Pre-Built Embeddings** - Embedding models downloaded during build (no runtime delays)
- **ARM64 Optimized** - Custom-compiled sqlite-vec for Apple Silicon and ARM64
- **HTTP-Only Mode** - Simple REST API and MCP protocol over HTTP
- **Management Scripts** - Easy-to-use scripts for building, running, and managing the service
- **Claude Code Integration** - Automated setup with slash commands and memory trigger hooks

## Quick Start

### Prerequisites

**Basic Setup:**
- **Docker Desktop** installed and running
- **Git** installed
- **Internet connection** (for initial setup)
- **Disk space**: ~3GB (for image + models)

**For Claude Code Integration (optional):**
- **Python 3.7+** (for hooks installer)
- **Node.js 14+** (for hook execution)
- **Claude Code** installed

### Installation

1. **Clone this repository**:
   ```bash
   git clone <this-repo-url>
   cd memory-docker
   ```

2. **Build and configure**:
   ```bash
   ./build.sh
   ```

   The script will:
   - Check Docker is running
   - Clone the mcp-memory-service repository
   - Prompt for your preferred database storage location
   - Build the Docker image (~3-5 minutes)
   - Generate a version manifest

3. **Start the service**:
   ```bash
   ./run.sh start
   ```

4. **Configure Claude Code** (choose one):

   **Option A: Automated (Recommended)**
   ```bash
   ./install-claude-code.sh
   ```

   **Option B: Manual**
   Add to `~/.claude/settings.json`:
   ```json
   {
     "mcpServers": {
       "memory": {
         "type": "http",
         "url": "http://localhost:8000/mcp"
       }
     }
   }
   ```

That's it! Your memory service is now running and connected to Claude Code.

## Claude Code Integration (Recommended)

For Claude Code users, we provide an automated setup script that:
- Registers the MCP server in your Claude Code settings
- Creates 7 helpful slash commands for memory operations
- **Installs memory trigger hooks** (core + natural language triggers)
- Supports both user-wide and project-local installation

### Prerequisites

For full integration including hooks:
- **Python 3.7+** (for hooks installer)
- **Node.js 14+** (for hook execution)
- **Claude Code** installed

The script will check prerequisites and guide you through any missing requirements.

### Quick Setup

```bash
./install-claude-code.sh
```

The script will:
1. Check if Claude Code is installed
2. Verify the memory service is running
3. Ask if you want user-wide or project-local installation
4. Register the MCP server configuration
5. Create slash commands for memory operations
6. Install memory trigger hooks with natural language detection

### Slash Commands Created

After installation, you'll have these commands available in Claude Code:

| Command | Description |
|---------|-------------|
| `/memory-status` | Check service status and statistics |
| `/memory-save` | Save information to memory |
| `/memory-search` | Search for memories by query |
| `/memory-recall` | Recall memories about a topic |
| `/memory-stats` | Show detailed memory statistics |
| `/memory-export` | Export memories to a file |
| `/memory-clear` | Clear memories (with confirmation) |

### Example Usage

```bash
# In Claude Code:
/memory-status
/memory-save Remember that the API key is stored in .env file
/memory-search API key
/memory-recall authentication setup
```

### Memory Trigger Hooks

The installer sets up intelligent memory awareness hooks from doobidoo's repository:

**Core Hooks:**
- `session-start.js` - Automatically loads relevant project memories when Claude Code launches
- `session-end.js` - Stores session insights and decisions for future reference
- `memory-retrieval.js` - Enables on-demand memory access during sessions
- `topic-change.js` - Detects context shifts and loads relevant memories

**Natural Language Triggers (v7.1.3):**
- `mid-conversation.js` - Real-time memory injection during active conversations
- Adaptive pattern detection with 85%+ trigger accuracy
- Multi-tier performance (50ms instant → 150ms fast → 500ms intensive)
- Git-aware context integration

**How They Work:**

1. **Session Start**: Automatically loads relevant memories based on:
   - Project context and git repository
   - Recent conversation history
   - Semantic similarity to current work
   - Time decay and relevance scoring

2. **During Conversation**: Intelligently detects when to inject memories:
   - Topic changes and context shifts
   - Questions that reference past work
   - Decisions that need historical context

3. **Session End**: Automatically captures:
   - Important decisions made
   - New insights and learnings
   - Project state and context

**Performance Modes:**

Configure with `memory-mode-controller.js`:
- **speed_focused** - Minimal latency, basic triggers only
- **balanced** - Good performance, smart triggers (default)
- **memory_aware** - Maximum context, intensive analysis

**Verification:**

After installation, test the hooks:
```bash
# Check hook detection
claude --debug hooks

# Run integration tests (if available)
node ~/.claude/hooks/tests/integration-test.js
```

### Manual Configuration

If you prefer to configure manually, add this to `~/.claude/settings.json`:

```json
{
  "mcpServers": {
    "memory": {
      "type": "http",
      "url": "http://localhost:8000/mcp"
    }
  }
}
```

For slash commands, create files in `~/.claude/commands/` (see `install-claude-code.sh` for examples).

## Directory Structure

After building, your directory will look like this:

```
memory-docker/
├── mcp-memory-service/      # Auto-cloned repository
├── Dockerfile               # ARM64-optimized image definition
├── docker-compose.yml       # Service orchestration
├── docker-entrypoint.sh     # Container startup script
├── build.sh                 # Build script (with auto-clone)
├── run.sh                   # Management script
├── install-claude-code.sh   # Claude Code integration installer
├── config.sh                # Auto-generated configuration
├── manifest.json            # Version tracking file
├── .gitignore              # Excludes generated files
└── data/                    # Database storage (configurable location)
    ├── sqlite_vec.db        # Vector database
    └── backups/             # Database backups
```

## Usage

### Build Script (`build.sh`)

Builds the Docker image and configures the service.

```bash
./build.sh                  # Normal build with prompts
./build.sh --no-cache       # Fresh build (ignores Docker cache)
./build.sh --verbose        # Detailed build output
./build.sh --help           # Show all options
```

**What it does**:
1. Checks Docker is running
2. Clones/updates the mcp-memory-service repository
3. Generates a version manifest
4. Prompts for database storage location
5. Builds the Docker image
6. Shows build statistics and next steps

**Build time**: 3-5 minutes (first build), ~1 minute (subsequent builds)
**Image size**: ~1.5-2GB (includes PyTorch CPU-only + embedding models)

### Management Script (`run.sh`)

Manages the running service.

```bash
./run.sh start              # Start the service
./run.sh stop               # Stop the service
./run.sh restart            # Restart the service
./run.sh status             # Show detailed status
./run.sh logs               # View logs (follow mode)
./run.sh logs-tail          # View last 100 lines
./run.sh health             # Check health endpoint
./run.sh shell              # Open shell in container
./run.sh ps                 # Show container processes
./run.sh stats              # Show resource usage (live)
./run.sh version            # Show repository version and manifest
./run.sh cleanup            # Remove container and volumes (DELETES DATA!)
./run.sh help               # Show all commands
```

## Configuration

### Database Storage Location

On first build, you'll be prompted to choose where to store your SQLite database:

```
Where would you like to store the SQLite database?
This directory will contain:
  - sqlite_vec.db (the vector database)
  - backups/ (database backups)

Default: ./data
Enter path (or press Enter for default):
```

You can specify:
- **Relative path**: `./data` or `../shared-data`
- **Absolute path**: `/Users/yourname/mcp-data`
- **Home directory**: `~/Documents/mcp-memory`

The path is saved in `config.sh` and used by both build and run scripts.

### Repository Updates

When you run `./build.sh` on subsequent builds:

```
📂 Source directory exists: ./mcp-memory-service
Update repository to latest version? (y/n)
```

- Press `y` to pull the latest changes from GitHub
- Press `n` to use the existing version

### Version Tracking

Every build generates a `manifest.json` file:

```json
{
  "repository": {
    "url": "https://github.com/doobidoo/mcp-memory-service",
    "commit": "abc123def456...",
    "commit_short": "abc123d",
    "branch": "main",
    "commit_date": "2025-01-19 10:30:00 -0800",
    "commit_message": "Fix memory leak in vector storage"
  },
  "build": {
    "date": "2025-01-19T18:45:23Z",
    "script_version": "1.0"
  }
}
```

View the manifest:
```bash
./run.sh version
```

This helps you track which version of the upstream repository you're running, making it easy to identify breaking changes.

## Service Endpoints

Once running, the service provides:

- **Web Dashboard**: http://localhost:8000/
- **MCP Endpoint**: http://localhost:8000/mcp (for Claude Code)
- **API Documentation**: http://localhost:8000/api/docs
- **Health Check**: http://localhost:8000/api/health

## Architecture Details

### HTTP-Only Mode

The service runs in HTTP-only mode with:
- ✅ MCP Protocol over HTTP (`/mcp` endpoint)
- ✅ REST API (`/api/*` endpoints)
- ✅ Web Dashboard (`/`)
- ✅ Server-Sent Events (`/api/events`)

### Pre-Downloaded Embeddings

The embedding model (`all-MiniLM-L6-v2`) is downloaded during the Docker build, not at runtime:
- ✅ No download delays on container startup
- ✅ Predictable startup time (2-3 seconds)
- ✅ Works offline after initial build
- ✅ Model cached in image (~90MB)

### ARM64 Optimization

The Dockerfile includes custom-compiled `sqlite-vec` for ARM64:
- Built from source during image build
- Optimized for Apple Silicon and ARM64 processors
- Avoids broken PyPI wheels
- Full compatibility with vector operations

### SQLite-vec Backend

Data storage:
- **Database**: Persistent SQLite file on host
- **Location**: Configurable (default: `./data/sqlite_vec.db`)
- **Backups**: Automatic backups to `data/backups/`
- **Performance**: ~5ms read/write operations

## Environment Variables

The service is configured via environment variables in `docker-compose.yml`:

```yaml
environment:
  # Storage backend
  - MCP_MEMORY_STORAGE_BACKEND=sqlite_vec
  - MCP_MEMORY_SQLITE_PATH=/app/data/sqlite_vec.db
  - MCP_MEMORY_BACKUPS_PATH=/app/data/backups

  # HTTP server
  - MCP_HTTP_ENABLED=true
  - MCP_HTTP_PORT=8000
  - MCP_HTTP_HOST=0.0.0.0

  # Embedding model
  - MCP_EMBEDDING_MODEL=all-MiniLM-L6-v2
  - MCP_MEMORY_USE_ONNX=false

  # Logging
  - LOG_LEVEL=INFO

  # Optional features (disabled for simplicity)
  - MCP_CONSOLIDATION_ENABLED=false
  - MCP_MDNS_ENABLED=false
  - MCP_OAUTH_ENABLED=false

  # SQLite optimizations
  - MCP_MEMORY_SQLITE_PRAGMAS=busy_timeout=15000,journal_mode=WAL
```

## Resource Limits

Default resource limits (configurable in `docker-compose.yml`):

```yaml
deploy:
  resources:
    limits:
      cpus: '2.0'          # Max 2 CPU cores
      memory: 2G           # Max 2GB RAM
    reservations:
      cpus: '0.5'          # Reserved 0.5 cores
      memory: 512M         # Reserved 512MB RAM
```

## Troubleshooting

### Container won't start

```bash
./run.sh logs               # Check logs for errors
docker ps -a                # Check container status
./build.sh --no-cache       # Rebuild from scratch
```

### Health check fails

```bash
curl http://localhost:8000/api/health    # Test directly
./run.sh status                          # Check detailed status
./run.sh logs                            # View error logs
```

### Port already in use

```bash
lsof -i :8000              # Find what's using port 8000
# Edit docker-compose.yml to use different port:
# ports: - "8001:8000"
```

### Database issues

```bash
./run.sh shell
# Inside container:
sqlite3 /app/data/sqlite_vec.db "PRAGMA integrity_check;"
```

### Reset everything

```bash
./run.sh cleanup           # Removes container and volumes
rm -rf mcp-memory-service  # Remove cloned repo
rm config.sh manifest.json # Remove configuration
./build.sh                 # Start fresh
```

## Updating

### Update to Latest Repository Version

```bash
./build.sh
# Answer 'y' when prompted to update repository
# Then restart:
./run.sh restart
```

### Update Docker Scripts

```bash
git pull                   # Pull latest script changes
./build.sh --no-cache      # Rebuild with new Dockerfile
./run.sh restart           # Restart service
```

## Advanced Usage

### Change Port

Edit `docker-compose.yml`:
```yaml
ports:
  - "3000:8000"  # Use port 3000 on host
```

### Custom Data Location

The data directory is set during build. To change it:
```bash
rm config.sh               # Remove existing config
./build.sh                 # Re-run build to set new location
```

### View Build Info

```bash
./run.sh version           # Show manifest
cat manifest.json          # View full version details
```

### Run Multiple Instances

```bash
# Copy and modify docker-compose.yml
cp docker-compose.yml docker-compose-2.yml

# Edit docker-compose-2.yml:
# - Change container_name to mcp-memory-service-2
# - Change ports to "8001:8000"
# - Change data volume if needed

# Start second instance
docker-compose -f docker-compose-2.yml up -d
```

## Performance Metrics

Expected performance on modern hardware:

| Metric | Value |
|--------|-------|
| Container startup | 2-3 seconds |
| Memory usage (idle) | 300-500MB |
| Memory usage (active) | 500MB-1GB |
| API response time | <100ms |
| Semantic search (10 results) | ~50ms |
| Database operations | ~5ms |

## Files Generated

The tool generates these files automatically:

- **`config.sh`** - Configuration with database path (gitignored)
- **`manifest.json`** - Version tracking (gitignored)
- **`mcp-memory-service/`** - Cloned repository (gitignored)
- **`data/`** - Database storage (gitignored)

These are excluded from git and regenerated on each build.

## Security Notes

This is a **development setup** optimized for ease of use:

- ⚠️ No authentication by default
- ⚠️ HTTP only (no TLS)
- ⚠️ Container runs as root
- ⚠️ Database files accessible on host

For production:
1. Enable OAuth: `MCP_OAUTH_ENABLED=true`
2. Use HTTPS with valid certificates
3. Set up API key authentication
4. Run container as non-root user
5. Use appropriate file permissions

## Contributing

Found an issue or want to improve the deployment scripts?

1. Check if issue exists in the [upstream repository](https://github.com/doobidoo/mcp-memory-service)
2. For Docker/deployment issues, create an issue in this repository
3. Include your manifest version: `./run.sh version`

## License

This deployment tool is provided as-is. The mcp-memory-service has its own license (see the [upstream repository](https://github.com/doobidoo/mcp-memory-service)).

## Support

- **Build Issues**: Run `./build.sh --verbose` for detailed output
- **Runtime Issues**: Check `./run.sh logs` for error messages
- **Version Check**: Use `./run.sh version` to see what you're running
- **Health Check**: Visit http://localhost:8000/api/health
- **API Docs**: Visit http://localhost:8000/api/docs

## Acknowledgments

- [doobidoo/mcp-memory-service](https://github.com/doobidoo/mcp-memory-service) - The upstream memory service
- [Model Context Protocol](https://modelcontextprotocol.io/) - MCP specification
- [Claude Code](https://claude.ai/claude-code) - AI coding assistant
