#!/usr/bin/env bash
set -euo pipefail

# Usage: open-nvim-pane.sh [file ...]
# Finds an adjacent Zellij pane running zsh/bash/fish or nvim and opens files there.
# If none exists, creates a vertical split pane and uses it.
# Exit codes:
#   0 — success
#   1 — unrecoverable failure

SELF_ID="${ZELLIJ_PANE_ID:?ZELLIJ_PANE_ID not set}"
FILES=("$@")

find_target() {
  zellij action list-panes --json | ZELLIJ_PANE_ID="$SELF_ID" python3 -c "
import json, sys, os

self_id = int(os.environ['ZELLIJ_PANE_ID'])
panes = json.load(sys.stdin)

# Find our tab_id. Pane IDs are not globally unique — the same numeric id
# can appear both as a plugin pane and as a terminal pane. This script always
# runs inside a terminal pane, so restrict the self match to non-plugin panes.
self_tab = None
for p in panes:
    if p['id'] == self_id and not p['is_plugin']:
        self_tab = p.get('tab_id')
        break

if self_tab is None:
    sys.exit(1)

shell_pane = None
nvim_pane = None
fallback_pane = None

def cmd_of(p):
    raw = p.get('terminal_command') or p.get('pane_command') or p.get('title') or ''
    # First token, basename
    tok = raw.split()[0] if raw else ''
    return tok.rsplit('/', 1)[-1].lower()

for p in panes:
    if p['is_plugin'] or p['id'] == self_id:
        continue
    if p.get('tab_id') != self_tab:
        continue
    cmd = cmd_of(p)
    if 'nvim' in cmd or 'vim' == cmd:
        nvim_pane = p['id']
    elif cmd in ('zsh', 'bash', 'fish', 'sh'):
        shell_pane = shell_pane or p['id']
    else:
        # Non-plugin pane with unknown command — assume it's a shell (zellij
        # often reports terminal_command as null for interactive shells).
        fallback_pane = fallback_pane or p['id']

if nvim_pane is not None:
    print(f'{nvim_pane} nvim')
elif shell_pane is not None:
    print(f'{shell_pane} shell')
elif fallback_pane is not None:
    print(f'{fallback_pane} shell')
else:
    print('- none')
"
}

read -r TARGET_ID TARGET_TYPE < <(find_target)

if [[ "$TARGET_TYPE" == "none" ]]; then
  # No suitable pane — create a vertical split and retry.
  zellij action new-pane --direction right
  # Give the new shell a moment to register and start its prompt.
  for _ in 1 2 3 4 5 6 7 8 9 10; do
    sleep 0.2
    read -r TARGET_ID TARGET_TYPE < <(find_target)
    [[ "$TARGET_TYPE" != "none" ]] && break
  done
  if [[ "$TARGET_TYPE" == "none" ]]; then
    echo "failed to create or detect new pane" >&2
    exit 1
  fi
  # Extra delay so the new shell is ready to receive chars.
  sleep 0.3
fi

if [[ "$TARGET_TYPE" == "nvim" ]]; then
  if [[ ${#FILES[@]} -eq 0 ]]; then
    # No files — just focus the existing nvim
    zellij action focus-pane-id "terminal_${TARGET_ID}" >/dev/null 2>&1 || true
  else
    # Open each file via :e in existing nvim
    for f in "${FILES[@]}"; do
      # Resolve to absolute path
      abs=$(cd "$(dirname "$f")" 2>/dev/null && echo "$(pwd)/$(basename "$f")" || echo "$f")
      zellij action write-chars -p "terminal_${TARGET_ID}" $'\x1b'":e ${abs}"$'\n'
    done
    zellij action focus-pane-id "terminal_${TARGET_ID}" >/dev/null 2>&1 || true
  fi
elif [[ "$TARGET_TYPE" == "shell" ]]; then
  if [[ ${#FILES[@]} -eq 0 ]]; then
    zellij action write-chars -p "terminal_${TARGET_ID}" $'nvim\n'
  else
    # Resolve all paths to absolute
    ABS_FILES=()
    for f in "${FILES[@]}"; do
      abs=$(cd "$(dirname "$f")" 2>/dev/null && echo "$(pwd)/$(basename "$f")" || echo "$f")
      ABS_FILES+=("$abs")
    done
    zellij action write-chars -p "terminal_${TARGET_ID}" "nvim ${ABS_FILES[*]}"$'\n'
  fi
  zellij action focus-pane-id "terminal_${TARGET_ID}" >/dev/null 2>&1 || true
fi

echo "opened in pane ${TARGET_ID} (${TARGET_TYPE})"
