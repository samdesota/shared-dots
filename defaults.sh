#!/usr/bin/env bash
# macOS default preferences. Idempotent — re-running just re-applies.
# Run after setup.sh, or any time you want to re-sync prefs.

set -euo pipefail

log() { printf '\033[1;34m==>\033[0m %s\n' "$*"; }

# ---------- Keyboard ----------
# KeyRepeat: how fast repeats fire once the key is held (lower = faster; 1 is min).
# InitialKeyRepeat: delay before repeat starts (lower = shorter; 10 is min via UI).
log "Keyboard: fast key repeat, short initial delay"
defaults write NSGlobalDomain KeyRepeat -int 1
defaults write NSGlobalDomain InitialKeyRepeat -int 10

# ---------- Dock ----------
log "Dock: right side, auto-hide, no reveal delay"
defaults write com.apple.dock orientation -string right
defaults write com.apple.dock autohide -bool true
# No pause before the dock slides in when the pointer hits the edge.
defaults write com.apple.dock autohide-delay -float 0
# Snappier slide animation (default is 0.5).
defaults write com.apple.dock autohide-time-modifier -float 0.3

# Apply dock changes.
killall Dock 2>/dev/null || true

log "Defaults applied. Keyboard changes take effect in new apps; log out/in for a full refresh."
