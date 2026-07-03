#!/usr/bin/env bash
set -euo pipefail

# fzf over my GitHub repos (personal + whitelisted orgs), prompt for a
# destination directory, then clone. Cached results show instantly; fzf
# reloads with fresh data as soon as gh returns.

OWNERS=(samdesota starch-stop)
DEFAULT_DEST="$HOME/d"
CACHE_DIR="${XDG_CACHE_HOME:-$HOME/.cache}/clone"
CACHE_FILE="$CACHE_DIR/repos.tsv"

fetch_repos() {
  local owner chunk
  for owner in "${OWNERS[@]}"; do
    if ! chunk=$(gh repo list "$owner" --limit 1000 \
      --json nameWithOwner,description,updatedAt \
      --jq 'sort_by(.updatedAt) | reverse | .[] | [.nameWithOwner, (.description // "")] | @tsv'); then
      return 1
    fi
    [ -n "$chunk" ] && printf '%s\n' "$chunk"
  done
}

# Internal: invoked recursively by fzf's start:reload binding.
if [ "${1:-}" = "--fetch-and-cache" ]; then
  mkdir -p "$CACHE_DIR"
  tmp="$(mktemp "$CACHE_DIR/repos.XXXXXX")"
  if fetch_repos > "$tmp" && [ -s "$tmp" ]; then
    mv "$tmp" "$CACHE_FILE"
    cat "$CACHE_FILE"
  else
    rm -f "$tmp"
    # Fetch failed — keep fzf showing whatever cache we had.
    [ -s "$CACHE_FILE" ] && cat "$CACHE_FILE"
  fi
  exit 0
fi

for cmd in gh fzf; do
  command -v "$cmd" >/dev/null 2>&1 || { echo "error: $cmd not found" >&2; exit 1; }
done

mkdir -p "$CACHE_DIR"

self="${BASH_SOURCE[0]}"
case "$self" in /*) ;; *) self="$PWD/$self" ;; esac

choice=$(fzf \
  --delimiter=$'\t' \
  --with-nth=1,2 \
  --height=80% \
  --prompt='repo> ' \
  --bind "start:reload:'$self' --fetch-and-cache" \
  < <(cat "$CACHE_FILE" 2>/dev/null || true)) || exit 130

repo="${choice%%$'\t'*}"
name="${repo##*/}"

read -r -p "clone into [$DEFAULT_DEST]: " dest
dest="${dest:-$DEFAULT_DEST}"
dest="${dest/#\~/$HOME}"

mkdir -p "$dest"
target="$dest/$name"

if [ -e "$target" ]; then
  echo "error: $target already exists" >&2
  exit 1
fi

gh repo clone "$repo" "$target"
echo ""
echo "cloned to $target"
