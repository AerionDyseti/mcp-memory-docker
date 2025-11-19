#!/bin/bash

# MCP Memory Service - Claude Code Integration Script
# Installs MCP server configuration and helpful slash commands

set -e

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
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

header() {
    echo -e "${CYAN}$1${NC}"
}

# Check if jq is installed (for JSON manipulation)
check_jq() {
    if ! command -v jq &> /dev/null; then
        warning "jq is not installed. Using python for JSON manipulation."
        return 1
    fi
    return 0
}

# Merge MCP server config into settings.json
merge_mcp_config() {
    local settings_file="$1"
    local server_name="$2"
    local server_config="$3"

    # Create backup
    if [ -f "$settings_file" ]; then
        cp "$settings_file" "${settings_file}.backup"
        info "Backup created: ${settings_file}.backup"
    fi

    # Use Python to safely merge JSON
    python3 << EOF
import json
import sys
from pathlib import Path

settings_file = Path("$settings_file")
server_name = "$server_name"
server_config = $server_config

# Load existing config or start fresh
if settings_file.exists():
    try:
        with open(settings_file, 'r') as f:
            config = json.load(f)
    except json.JSONDecodeError:
        print("Warning: Existing settings.json is invalid. Starting fresh.", file=sys.stderr)
        config = {}
else:
    config = {}

# Ensure mcpServers exists
if "mcpServers" not in config:
    config["mcpServers"] = {}

# Add or update the memory server
config["mcpServers"][server_name] = server_config

# Ensure parent directory exists
settings_file.parent.mkdir(parents=True, exist_ok=True)

# Write back
try:
    with open(settings_file, 'w') as f:
        json.dump(config, f, indent=2)
    print(f"Success: MCP server '{server_name}' registered")
except Exception as e:
    print(f"Error writing settings: {e}", file=sys.stderr)
    sys.exit(1)
EOF

    return $?
}

# Create slash command
create_slash_command() {
    local command_name="$1"
    local description="$2"
    local content="$3"
    local commands_dir="$4"

    mkdir -p "$commands_dir"

    cat > "$commands_dir/${command_name}.md" << EOF
---
description: $description
---

$content
EOF

    success "Created slash command: /$command_name"
}

# Main installation
echo ""
header "=========================================="
header "MCP Memory Service - Claude Code Setup"
header "=========================================="
echo ""

# Check if Claude Code is installed
CLAUDE_HOME="$HOME/.claude"
if [ ! -d "$CLAUDE_HOME" ]; then
    error "Claude Code not found at $CLAUDE_HOME"
    echo ""
    echo "Please install Claude Code first:"
    echo "  https://claude.ai/claude-code"
    exit 1
fi

success "Claude Code found at $CLAUDE_HOME"
echo ""

# Check if memory service is running
info "Checking if memory service is running..."
if curl -sf http://localhost:8000/api/health > /dev/null 2>&1; then
    success "Memory service is running"
else
    warning "Memory service is not running"
    echo "   Start it with: ./run.sh start"
    echo ""
    read -p "Continue anyway? (y/n) " -n 1 -r
    echo ""
    if [[ ! $REPLY =~ ^[Yy]$ ]]; then
        info "Installation cancelled"
        exit 0
    fi
fi

echo ""
header "Configuration Options"
echo ""
echo "Choose installation scope:"
echo "  1. User-wide (recommended) - Available in all projects"
echo "  2. Project-local - Only in current project directory"
echo ""
read -p "Enter choice (1 or 2): " -n 1 -r SCOPE_CHOICE
echo ""
echo ""

if [[ "$SCOPE_CHOICE" == "1" ]]; then
    SETTINGS_FILE="$HOME/.claude/settings.json"
    COMMANDS_DIR="$HOME/.claude/commands"
    SCOPE_NAME="user-wide"
elif [[ "$SCOPE_CHOICE" == "2" ]]; then
    SETTINGS_FILE="./.claude/settings.json"
    COMMANDS_DIR="./.claude/commands"
    SCOPE_NAME="project-local"
else
    error "Invalid choice"
    exit 1
fi

echo ""
header "Installing ($SCOPE_NAME)..."
echo ""

# Step 1: Register MCP Server
info "Registering MCP server in settings.json..."
SERVER_CONFIG='{
  "type": "http",
  "url": "http://localhost:8000/mcp"
}'

if merge_mcp_config "$SETTINGS_FILE" "memory" "$SERVER_CONFIG"; then
    success "MCP server registered in $SETTINGS_FILE"
else
    error "Failed to register MCP server"
    exit 1
fi

echo ""

# Step 2: Create slash commands
header "Creating Slash Commands"
echo ""

# /memory-status command
create_slash_command "memory-status" \
    "Check memory service status and statistics" \
    "Check the status of the MCP memory service and provide a summary of:
1. Service health and availability
2. Number of stored memories
3. Recent activity
4. Database statistics

Use the appropriate MCP tools to gather this information." \
    "$COMMANDS_DIR"

# /memory-save command
create_slash_command "memory-save" \
    "Save important information to memory" \
    "Save the following information to the MCP memory service:

\$1

Make sure to:
1. Use appropriate entities and tags
2. Add relevant context
3. Confirm the memory was saved successfully" \
    "$COMMANDS_DIR"

# /memory-search command
create_slash_command "memory-search" \
    "Search memories by query" \
    "Search the MCP memory service for: \$1

Provide:
1. Relevant memories found
2. Similarity scores
3. Context from each memory
4. Suggestions for refining the search if needed" \
    "$COMMANDS_DIR"

# /memory-recall command
create_slash_command "memory-recall" \
    "Recall memories about a topic" \
    "Recall and summarize all memories related to: \$1

Provide:
1. A comprehensive summary of what is remembered
2. Related entities and connections
3. Timeline if relevant
4. Any gaps in memory" \
    "$COMMANDS_DIR"

# /memory-stats command
create_slash_command "memory-stats" \
    "Show detailed memory statistics" \
    "Provide detailed statistics about the MCP memory service:
1. Total number of memories
2. Storage usage
3. Most common entities
4. Recent activity summary
5. Database health metrics

Present the information in a clear, formatted way." \
    "$COMMANDS_DIR"

# /memory-export command
create_slash_command "memory-export" \
    "Export memories to a file" \
    "Export memories from the MCP memory service.

If a query is provided (\$1), export only matching memories.
Otherwise, export all memories.

Save to a JSON file and provide:
1. Export summary (count, size)
2. File location
3. Format description" \
    "$COMMANDS_DIR"

# /memory-clear command
create_slash_command "memory-clear" \
    "Clear memories (with confirmation)" \
    "⚠️  WARNING: This will delete memories!

Query to clear: \$1

Before proceeding:
1. Show what will be deleted
2. Ask for explicit confirmation
3. Only proceed if user confirms with 'yes'

If confirmed, delete the memories and provide a summary of what was removed." \
    "$COMMANDS_DIR"

echo ""

# Step 3: Install memory trigger hooks
header "Installing Memory Trigger Hooks"
echo ""

# Check if repository has been cloned
REPO_DIR="./mcp-memory-service"
if [ ! -d "$REPO_DIR" ]; then
    warning "mcp-memory-service repository not found"
    echo "   Run ./build.sh first to clone the repository"
    echo ""
    read -p "Skip hooks installation? (y/n) " -n 1 -r
    echo ""
    if [[ $REPLY =~ ^[Yy]$ ]]; then
        warning "Skipping hooks installation"
        HOOKS_INSTALLED=false
    else
        error "Cannot proceed without repository"
        exit 1
    fi
else
    HOOKS_DIR="$REPO_DIR/claude-hooks"

    if [ ! -d "$HOOKS_DIR" ]; then
        warning "claude-hooks directory not found in repository"
        echo "   This may be expected if the repository structure has changed"
        HOOKS_INSTALLED=false
    else
        # Check prerequisites
        info "Checking prerequisites for hooks..."

        PREREQ_OK=true

        if ! command -v python3 &> /dev/null; then
            error "Python 3 is required for hooks installation"
            PREREQ_OK=false
        else
            PYTHON_VERSION=$(python3 --version 2>&1 | grep -oP '\d+\.\d+' | head -1)
            PYTHON_MAJOR=$(echo $PYTHON_VERSION | cut -d. -f1)
            PYTHON_MINOR=$(echo $PYTHON_VERSION | cut -d. -f2)
            if [ "$PYTHON_MAJOR" -lt 3 ] || { [ "$PYTHON_MAJOR" -eq 3 ] && [ "$PYTHON_MINOR" -lt 7 ]; }; then
                error "Python 3.7+ is required (found $PYTHON_VERSION)"
                PREREQ_OK=false
            else
                success "Python $PYTHON_VERSION found"
            fi
        fi

        if ! command -v node &> /dev/null; then
            warning "Node.js not found - required for hooks"
            PREREQ_OK=false
        else
            NODE_VERSION=$(node --version 2>&1 | grep -oP '\d+' | head -1)
            if [ "$NODE_VERSION" -lt 14 ]; then
                warning "Node.js 14+ recommended (found v$NODE_VERSION)"
            else
                success "Node.js v$NODE_VERSION found"
            fi
        fi

        if [ "$PREREQ_OK" = true ]; then
            echo ""
            info "Installing hooks with natural language triggers..."
            echo ""

            # Navigate to hooks directory and run installer
            cd "$HOOKS_DIR"

            if python3 install_hooks.py --natural-triggers; then
                success "Memory trigger hooks installed successfully"
                HOOKS_INSTALLED=true

                # Show what was installed
                echo ""
                info "Installed hooks:"
                echo "  • Core hooks (session-start, session-end, memory-retrieval)"
                echo "  • Natural language triggers (mid-conversation detection)"
                echo "  • Utilities and performance management"
                echo ""

                # Check for CLI controller
                if [ -f "$HOME/.claude/hooks/memory-mode-controller.js" ]; then
                    info "CLI controller available: memory-mode-controller.js"
                    echo "  • Manage trigger modes: speed_focused, balanced, memory_aware"
                fi
            else
                error "Failed to install hooks"
                HOOKS_INSTALLED=false
            fi

            # Return to original directory
            cd - > /dev/null
        else
            warning "Prerequisites not met - skipping hooks installation"
            echo ""
            echo "To install hooks later:"
            echo "  1. Install Python 3.7+ and Node.js 14+"
            echo "  2. Run: cd $HOOKS_DIR && python3 install_hooks.py --natural-triggers"
            echo ""
            HOOKS_INSTALLED=false
        fi
    fi
fi

echo ""
header "=========================================="
header "Installation Complete!"
header "=========================================="
echo ""

success "MCP server registered: memory"
success "Slash commands created: 7 commands"
if [ "${HOOKS_INSTALLED:-false}" = true ]; then
    success "Memory trigger hooks installed"
else
    warning "Hooks not installed (see above)"
fi
echo ""

echo "Available Commands:"
echo ""
echo "  ${CYAN}/memory-status${NC}       Check service status and statistics"
echo "  ${CYAN}/memory-save${NC}         Save information to memory"
echo "  ${CYAN}/memory-search${NC}       Search for memories"
echo "  ${CYAN}/memory-recall${NC}       Recall memories about a topic"
echo "  ${CYAN}/memory-stats${NC}        Show detailed statistics"
echo "  ${CYAN}/memory-export${NC}       Export memories to file"
echo "  ${CYAN}/memory-clear${NC}        Clear memories (with confirmation)"
echo ""

echo "Configuration Location:"
echo "  Settings: $SETTINGS_FILE"
echo "  Commands: $COMMANDS_DIR"
echo ""

if [ -f "${SETTINGS_FILE}.backup" ]; then
    info "Backup saved: ${SETTINGS_FILE}.backup"
    echo ""
fi

echo "Quick Test:"
echo "  1. Restart Claude Code (if running)"
echo "  2. Open any project directory"
echo "  3. Type ${CYAN}/memory-status${NC} to test the integration"
echo ""

header "Next Steps"
echo ""
echo "1. Make sure the service is running:"
echo "   ${CYAN}./run.sh start${NC}"
echo ""
echo "2. Check the service status:"
echo "   ${CYAN}./run.sh status${NC}"
echo ""
echo "3. Restart Claude Code to activate hooks"
echo ""
echo "4. In Claude Code, try the slash commands:"
echo "   ${CYAN}/memory-status${NC}"
echo "   ${CYAN}/memory-save Remember this important fact${NC}"
echo "   ${CYAN}/memory-search important${NC}"
echo ""

if [ "${HOOKS_INSTALLED:-false}" = true ]; then
    header "Memory Trigger Hooks"
    echo ""
    echo "The hooks will automatically:"
    echo "  • Load relevant memories when starting a session"
    echo "  • Detect context changes during conversation"
    echo "  • Save important decisions at session end"
    echo ""
    echo "Hook modes (configure with memory-mode-controller.js):"
    echo "  • ${CYAN}speed_focused${NC}   - Minimal latency, basic triggers"
    echo "  • ${CYAN}balanced${NC}        - Good performance, smart triggers (default)"
    echo "  • ${CYAN}memory_aware${NC}    - Maximum context, intensive analysis"
    echo ""
fi

success "Setup complete! Happy coding with persistent memory!"
echo ""
