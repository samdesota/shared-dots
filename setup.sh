#!/usr/bin/env bash
# One-time bootstrap for a fresh mac. Installs Xcode CLT, Homebrew, and
# critical tools. Idempotent — re-running is safe.
#
# After this finishes, run ./install.sh to link configs.

set -euo pipefail

log()  { printf '\033[1;34m==>\033[0m %s\n' "$*"; }
warn() { printf '\033[1;33m!!\033[0m %s\n' "$*"; }

have() { command -v "$1" >/dev/null 2>&1; }

# ---------- Xcode Command Line Tools ----------
if ! xcode-select -p >/dev/null 2>&1; then
  log "Installing Xcode Command Line Tools (GUI prompt will appear)"
  xcode-select --install || true
  warn "Re-run setup.sh once the Xcode CLT install finishes."
  exit 0
fi

# ---------- Homebrew ----------
if ! have brew; then
  log "Installing Homebrew"
  /bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"
fi

# Make sure brew is on PATH for the rest of this script
if [ -x /opt/homebrew/bin/brew ]; then
  eval "$(/opt/homebrew/bin/brew shellenv)"
elif [ -x /usr/local/bin/brew ]; then
  eval "$(/usr/local/bin/brew shellenv)"
fi

# ---------- Brew formulae ----------
BREW_FORMULAE=(
  # shell + editor
  zellij
  neovim
  tmux
  # vcs + dev
  git
  gh
  # runtimes / package managers
  nvm
  pnpm
  oven-sh/bun/bun
  # core CLI utilities used by .zshrc / day-to-day
  jq
  fzf
  ripgrep
  fd
  # 1Password CLI (used by ops/opass functions in .zshrc)
  1password-cli
)

log "Installing brew formulae"
for f in "${BREW_FORMULAE[@]}"; do
  name="${f##*/}"
  if brew list --formula "$name" >/dev/null 2>&1; then
    echo "  ✓ $name"
  else
    log "brew install $f"
    brew install "$f"
  fi
done

# ---------- Brew casks (GUI apps with configs in this repo) ----------
BREW_CASKS=(
  hammerspoon
  karabiner-elements
  raycast
)

log "Installing brew casks"
for c in "${BREW_CASKS[@]}"; do
  if brew list --cask "$c" >/dev/null 2>&1; then
    echo "  ✓ $c"
  else
    log "brew install --cask $c"
    brew install --cask "$c"
  fi
done

# ---------- Node via nvm ----------
export NVM_DIR="$HOME/.nvm"
mkdir -p "$NVM_DIR"
NVM_SH="$(brew --prefix)/opt/nvm/nvm.sh"
if [ -s "$NVM_SH" ]; then
  # shellcheck disable=SC1090
  . "$NVM_SH"
  if ! nvm ls --no-colors | grep -q 'lts'; then
    log "Installing Node LTS via nvm"
    nvm install --lts
    nvm alias default 'lts/*'
  else
    echo "  ✓ Node LTS already installed"
  fi
else
  warn "nvm.sh not found at $NVM_SH; skipping Node install"
fi

# ---------- Claude Code CLI ----------
if have npm; then
  if ! have claude; then
    log "Installing Claude Code CLI"
    npm install -g @anthropic-ai/claude-code
  else
    echo "  ✓ claude already installed"
  fi
else
  warn "npm not on PATH yet — open a new shell and run: npm install -g @anthropic-ai/claude-code"
fi

# ---------- macOS defaults ----------
if [ -x "$(dirname "$0")/defaults.sh" ]; then
  log "Applying macOS default preferences"
  "$(dirname "$0")/defaults.sh"
fi

log "Bootstrap done."
log "Next: run ./install.sh to link configs, then edit ~/.env.local to add secrets."
