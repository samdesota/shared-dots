#!/usr/bin/env bash
# Single-command bootstrap: pull latest, symlink configs into $HOME,
# then run the karabiner/hammerspoon build+reload flow.
#
# Idempotent. Safe to run repeatedly. Existing non-symlink files at a
# target path are moved aside to <path>.bak-<timestamp>.

set -euo pipefail

SHARED_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
HOME_SRC="$SHARED_DIR/home"
STAMP="$(date +%Y%m%d-%H%M%S)"

log()  { printf '\033[1;34m==>\033[0m %s\n' "$*"; }
warn() { printf '\033[1;33m!!\033[0m %s\n' "$*"; }

# ---------- 1. pull ----------
if [ -d "$SHARED_DIR/.git" ]; then
  log "Pulling latest in $SHARED_DIR"
  git -C "$SHARED_DIR" pull --ff-only || warn "git pull failed; continuing with local copy"
fi

# ---------- 2. ensure ~/.env.local ----------
if [ ! -f "$HOME/.env.local" ]; then
  log "Creating ~/.env.local from template (fill in secrets!)"
  cp "$SHARED_DIR/.env.local.example" "$HOME/.env.local"
  chmod 600 "$HOME/.env.local"
  warn "Edit ~/.env.local and add your real OPENAI_API_KEY"
fi

# ---------- 3. link ----------
# Symlink each entry in home/ into $HOME. Directories under .config/ are
# linked as directory symlinks; dotfiles at the top level are linked as files.
link() {
  local src="$1" dst="$2"
  mkdir -p "$(dirname "$dst")"
  if [ -L "$dst" ]; then
    local cur; cur="$(readlink "$dst")"
    if [ "$cur" = "$src" ]; then
      return 0
    fi
    rm "$dst"
  elif [ -e "$dst" ]; then
    warn "Backing up existing $dst -> $dst.bak-$STAMP"
    mv "$dst" "$dst.bak-$STAMP"
  fi
  ln -s "$src" "$dst"
  log "linked $dst -> $src"
}

# Top-level dotfiles in $HOME
for f in .zshrc .gitconfig; do
  [ -e "$HOME_SRC/$f" ] && link "$HOME_SRC/$f" "$HOME/$f"
done

# .raycast-scripts (whole dir)
[ -d "$HOME_SRC/.raycast-scripts" ] && link "$HOME_SRC/.raycast-scripts" "$HOME/.raycast-scripts"

# .config/* directories (link whole dirs so tools can write lockfiles alongside)
if [ -d "$HOME_SRC/.config" ]; then
  for d in "$HOME_SRC/.config"/*; do
    [ -e "$d" ] || continue
    name="$(basename "$d")"
    if [ "$name" = "git" ]; then
      # Merge: only link the ignore file, don't clobber user's other git config
      link "$d/ignore" "$HOME/.config/git/ignore"
    else
      link "$d" "$HOME/.config/$name"
    fi
  done
fi

# Agent config: merge per-item so machine-local state (sessions, history,
# settings.json, machine-only skills like codebase-memory) is preserved.
link_agent_config() {
  local target_dir="$1"
  mkdir -p "$target_dir/skills" "$target_dir/hooks"
  [ -f "$HOME_SRC/.agents/CLAUDE.md" ] && link "$HOME_SRC/.agents/CLAUDE.md" "$target_dir/CLAUDE.md"
  for s in "$HOME_SRC/.agents/skills"/*; do
    [ -e "$s" ] || continue
    link "$s" "$target_dir/skills/$(basename "$s")"
  done
  for h in "$HOME_SRC/.agents/hooks"/*; do
    [ -e "$h" ] || continue
    link "$h" "$target_dir/hooks/$(basename "$h")"
  done
}

if [ -d "$HOME_SRC/.agents" ]; then
  link_agent_config "$HOME/.agents"
  link_agent_config "$HOME/.claude"
fi

# ---------- 4. shared scripts ----------
# Any top-level dir containing <name>/<name>.sh gets linked into ~/.local/bin
# as an executable named <name>. This is the convention used by `nscr`.
mkdir -p "$HOME/.local/bin"
for d in "$SHARED_DIR"/*/; do
  name="$(basename "$d")"
  script="$d$name.sh"
  if [ -f "$script" ]; then
    chmod +x "$script" 2>/dev/null || true
    link "$script" "$HOME/.local/bin/$name"
  fi
done

# ---------- 5. karabiner / hammerspoon ----------
if [ -d "$SHARED_DIR/karabiner" ] && command -v pnpm >/dev/null 2>&1; then
  log "Building karabiner config"
  (cd "$SHARED_DIR/karabiner" && pnpm install && pnpm run build)
else
  warn "Skipping karabiner build (pnpm missing or dir absent)"
fi

if [ -d "$SHARED_DIR/hammerspoon" ] && command -v hs >/dev/null 2>&1; then
  log "Pointing Hammerspoon at shared config and reloading"
  defaults write org.hammerspoon.Hammerspoon MJConfigFile "$SHARED_DIR/hammerspoon/init.lua"
  hs -c "hs.reload()" || warn "hs reload failed (is Hammerspoon running?)"
else
  warn "Skipping hammerspoon (hs CLI missing or dir absent)"
fi

log "Done."
