#!/usr/bin/env bash
# Create a new shared script scaffold and open a Claude session on it.
#
# Usage: nscr <name>
#
# Creates ~/.config/shared/<name>/<name>.sh with an executable stub, opens
# a new zellij tab focused on the directory, and launches `claude` there.
# Run install.sh afterwards to symlink the new script into ~/.local/bin.

set -euo pipefail

if [ $# -lt 1 ] || [ -z "$1" ]; then
  echo "Usage: nscr <name>" >&2
  exit 1
fi

NAME="$1"

case "$NAME" in
  */*|.*|*" "*)
    echo "Error: name must be a simple identifier (no slashes, dots, or spaces)" >&2
    exit 1
    ;;
esac

SHARED_DIR="$HOME/.config/shared"
DIR="$SHARED_DIR/$NAME"
SCRIPT="$DIR/$NAME.sh"

if [ -e "$DIR" ]; then
  echo "Opening existing $DIR"
else
  mkdir -p "$DIR"
  cat > "$SCRIPT" <<EOF
#!/usr/bin/env bash
set -euo pipefail

EOF
  chmod +x "$SCRIPT"
  echo "Created $SCRIPT"
fi

if command -v zellij >/dev/null 2>&1 && [ -n "${ZELLIJ:-}" ]; then
  zellij action new-tab --cwd "$DIR" --name "$NAME"
  # Give zellij a moment to spawn the shell before typing.
  sleep 0.3
  # `cl` is the user's interactive-shell alias for
  # `IS_SANDBOX=1 claude --dangerously-skip-permissions`.
  zellij action write-chars $'cl\n'
else
  cd "$DIR"
  IS_SANDBOX=1 exec claude --dangerously-skip-permissions
fi
