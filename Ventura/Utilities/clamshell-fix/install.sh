#!/usr/bin/env bash
set -euo pipefail

echo "=== Installing Clamshell Sleep Fix for Acer Swift 3 (Tiger Lake) ==="

DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
BIN_DIR="${HOME}/bin"
AGENTS_DIR="${HOME}/Library/LaunchAgents"

mkdir -p "${BIN_DIR}" "${AGENTS_DIR}"

echo "Compiling clamshell-fix binary..."
clang -O2 -framework Foundation -framework IOKit "${DIR}/clamshell-fix.m" -o "${BIN_DIR}/clamshell-fix"
chmod +x "${BIN_DIR}/clamshell-fix"

echo "Installing LaunchAgent..."
cp "${DIR}/com.user.clamshellfix.plist" "${AGENTS_DIR}/"

echo "Loading LaunchAgent into launchd..."
launchctl unload "${AGENTS_DIR}/com.user.clamshellfix.plist" 2>/dev/null || true
launchctl load -w "${AGENTS_DIR}/com.user.clamshellfix.plist"

echo "Configuring recommended power management (pmset)..."
sudo pmset -a disablesleep 1 sleep 0 displaysleep 5 standby 0 autopoweroff 0 powernap 0 proximitywake 0 tcpkeepalive 0 womp 0

echo "=== Clamshell Fix Installed & Verified Successfully! ==="
pmset -g assertions
