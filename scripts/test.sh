#!/bin/zsh
set -euo pipefail
PROJECT_DIR="$(cd "$(dirname "$0")/.." && pwd)"
mkdir -p "$PROJECT_DIR/build"
swiftc -swift-version 5 "$PROJECT_DIR/Sources/LightingProtocol.swift" "$PROJECT_DIR/Sources/KeyMapping.swift" "$PROJECT_DIR/Tests/main.swift" -o "$PROJECT_DIR/build/ProtocolTests"
"$PROJECT_DIR/build/ProtocolTests"
