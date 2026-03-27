#!/bin/bash
set -e
cd "$(dirname "$0")"

echo "Building release binary..."
swift build -c release 2>&1

echo "Copying binary to bundle..."
cp .build/release/HikingMCPServer bundle/bin/hiking-mcp-server

echo "Packing .mcpb..."
cd bundle
zip -r ../../hiking-data.mcpb manifest.json bin/hiking-mcp-server
cd ..

echo ""
echo "Done! Created hiking-data.mcpb"
echo "Double-click to install in Claude Desktop."
