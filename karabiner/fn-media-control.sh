#!/usr/bin/env bash
set -euo pipefail

MEDIA_CONTROL="/opt/homebrew/bin/media-control"
HOLD_STATE_FILE="/tmp/karabiner-fn-media-hold-was-playing"
TAP_STATE_FILE="/tmp/karabiner-fn-media-tap-was-playing"
TAP_ACTIVE_FILE="/tmp/karabiner-fn-media-tap-active"
TAP_CLOSING_FILE="/tmp/karabiner-fn-media-tap-closing"
LOG_FILE="/tmp/karabiner-fn-media-control.log"

log() {
  printf '%s %s\n' "$(date -u '+%Y-%m-%dT%H:%M:%SZ')" "$*" >>"$LOG_FILE"
}

pause_if_playing() {
  local state_file="$1"
  local source="$2"

  rm -f "$state_file"
  if "$MEDIA_CONTROL" get --no-artwork | /usr/bin/grep -q '"playing":true'; then
    "$MEDIA_CONTROL" pause
    printf 'media\n' >"$state_file"
    log "paused via media-control for $source"
  else
    log "nothing playing for $source"
  fi
}

resume_if_paused() {
  local state_file="$1"
  local source="$2"

  if [ -f "$state_file" ]; then
    "$MEDIA_CONTROL" play
    rm -f "$state_file"
    log "resumed via media-control for $source"
  else
    log "nothing to resume for $source"
  fi
}

case "${1:-}" in
  pause-if-playing)
    pause_if_playing "$HOLD_STATE_FILE" "legacy"
    ;;

  resume-if-paused)
    resume_if_paused "$HOLD_STATE_FILE" "legacy"
    ;;

  pause-hold)
    pause_if_playing "$HOLD_STATE_FILE" "hold"
    ;;

  resume-hold)
    resume_if_paused "$HOLD_STATE_FILE" "hold"
    ;;

  tap-before)
    if [ -f "$TAP_ACTIVE_FILE" ]; then
      printf 'closing\n' >"$TAP_CLOSING_FILE"
      log "closing tap session"
    else
      rm -f "$TAP_CLOSING_FILE"
      pause_if_playing "$TAP_STATE_FILE" "tap"
      printf 'active\n' >"$TAP_ACTIVE_FILE"
      log "opened tap session"
    fi
    ;;

  tap-after)
    if [ -f "$TAP_CLOSING_FILE" ]; then
      resume_if_paused "$TAP_STATE_FILE" "tap"
      rm -f "$TAP_ACTIVE_FILE" "$TAP_CLOSING_FILE"
      log "closed tap session"
    fi
    ;;

  *)
    printf 'usage: %s pause-if-playing|resume-if-paused|pause-hold|resume-hold|tap-before|tap-after\n' "$0" >&2
    exit 64
    ;;
esac
