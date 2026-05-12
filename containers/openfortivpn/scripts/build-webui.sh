#!/usr/bin/env bash
set -euo pipefail

# Build webui for embedding into Go binary
# Called via go:generate from cmd/server/main.go

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"
WEBUI_DIR="$PROJECT_ROOT/webui"
DIST_TARGET="$PROJECT_ROOT/control-plane/cmd/server/webui/dist"

echo "Building webui..."

cd "$WEBUI_DIR"

if command -v bun >/dev/null 2>&1; then
    bun install
    bun run build
elif command -v npm >/dev/null 2>&1; then
    npm install
    npm run build
else
    echo "ERROR: No package manager found (bun or npm required)" >&2
    exit 1
fi

mkdir -p "$DIST_TARGET"
rm -rf "$DIST_TARGET"
cp -r "$WEBUI_DIR/dist" "$DIST_TARGET"

echo "Web UI built and copied to $DIST_TARGET"
