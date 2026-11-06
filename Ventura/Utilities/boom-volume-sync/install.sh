#!/usr/bin/env bash
set -euo pipefail

echo "=== Installing Boom 3D / WhatsApp Volume Sync Service ==="

DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
BIN_DIR="${HOME}/bin"
AGENTS_DIR="${HOME}/Library/LaunchAgents"

mkdir -p "${BIN_DIR}" "${AGENTS_DIR}"

echo "Compiling boom-volume-sync binary..."
clang -O2 -framework Foundation -framework CoreAudio -framework AudioToolbox "${DIR}/boom-volume-sync.m" -o "${BIN_DIR}/boom-volume-sync"
chmod +x "${BIN_DIR}/boom-volume-sync"

echo "Installing LaunchAgent..."
cp "${DIR}/com.user.boomvolumesync.plist" "${AGENTS_DIR}/"

echo "Loading LaunchAgent into launchd..."
launchctl unload "${AGENTS_DIR}/com.user.boomvolumesync.plist" 2>/dev/null || true
launchctl load -w "${AGENTS_DIR}/com.user.boomvolumesync.plist"

echo "=== Boom Volume Sync Service Installed & Running! ==="
launchctl list | grep "boomvolumesync"
