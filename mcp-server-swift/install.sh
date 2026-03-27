#!/bin/bash
set -e
cd "$(dirname "$0")"
echo "Building HikingMCPServer..."
swift build -c release 2>&1
BINARY=".build/release/HikingMCPServer"
DEST="/usr/local/bin/hiking-mcp-server"
echo "Installing to $DEST..."
cp "$BINARY" "$DEST"
echo "Done! Binary installed at $DEST"
echo ""
echo "Claude Desktop config (claude_desktop_config.json):"
echo '{'
echo '  "mcpServers": {'
echo '    "hiking": {'
echo '      "command": "hiking-mcp-server"'
echo '    }'
echo '  }'
echo '}'
