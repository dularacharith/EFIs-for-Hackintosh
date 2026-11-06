#!/bin/bash
set -e

DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"
mkdir -p ~/bin
clang -framework Foundation -framework CoreGraphics -framework IOKit -O2 "$DIR/idle-lock.m" -o ~/bin/idle-lock

mkdir -p ~/Library/LaunchAgents
cp "$DIR/com.user.idlelock.plist" ~/Library/LaunchAgents/
launchctl unload ~/Library/LaunchAgents/com.user.idlelock.plist 2>/dev/null || true
launchctl load ~/Library/LaunchAgents/com.user.idlelock.plist

echo "[OK] idle-lock installed and started. Display sleep prevented to protect Tiger Lake eDP link."
