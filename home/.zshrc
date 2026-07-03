
if [[ $(uname -m) == "x86_64" ]]; then
    export HOMEBREW_PREFIX="/usr/local"
else
    export HOMEBREW_PREFIX="/opt/homebrew"
fi


export FLYCTL_INSTALL="/Users/sam/.fly"
export PATH="$FLYCTL_INSTALL/bin:$PATH"


export NVM_DIR="$HOME/.nvm"
[ -s "$HOMEBREW_PREFIX/opt/nvm/nvm.sh" ] && \. "$HOMEBREW_PREFIX/opt/nvm/nvm.sh" # This loads nvm
[ -s "$HOMEBREW_PREFIX/opt/nvm/etc/bash_completion.d/nvm" ] && \. "$HOMEBREW_PREFIX/opt/nvm/etc/bash_completion.d/nvm" # This loads nvm bash_completion

export PATH="/usr/local/homebrew/opt/node@16/bin:$PATH"
export PATH="/usr/local/homebrew/bin:$PATH"
export PATH="/Users/samueldesota/.local/bin:$PATH"
export PATH="$HOME/d/daw/:$PATH"
export EDITOR="code --wait"
export AWS_REGION="us-east-1"

# Automatically use .nvmrc version when entering a directory
autoload -U add-zsh-hook
load-nvmrc() {
  local node_version="$(nvm version)"
  local nvmrc_path="$(nvm_find_nvmrc)"

  if [ -n "$nvmrc_path" ]; then
    local nvmrc_node_version=$(nvm version "$(cat "${nvmrc_path}")")

    if [ "$nvmrc_node_version" = "N/A" ]; then
      nvm install
    elif [ "$nvmrc_node_version" != "$node_version" ]; then
      nvm use
    fi
  elif [ "$node_version" != "$(nvm version default)" ]; then
    echo "Reverting to nvm default version"
    nvm use default
  fi
}
add-zsh-hook chpwd load-nvmrc
load-nvmrc

kill-node-port() {
  lsof -i ":$1" | grep node | awk '{print $2}' | xargs kill
}

#source $HOME/.zsh-vi-mode/zsh-vi-mode.plugin.zsh

fco() {
  local tags branches target
  tags=$(
    git tag | awk '{print "\x1b[31;1mtag\x1b[m\t" $1}') || return
  branches=$(
    git branch --all | grep -v HEAD             |
    sed "s/.* //"    | sed "s#remotes/[^/]*/##" |
    sort -u          | awk '{print "\x1b[34;1mbranch\x1b[m\t" $1}') || return
  target=$(
    (echo "$tags"; echo "$branches") |
    fzf-tmux -l30 -- --no-hscroll --ansi +m -d "\t" -n 2) || return
  git checkout $(echo "$target" | awk '{print $2}')
}

pcode() {
  local branches branch
  folders=$(node $HOME/d/raycast-scripts/scripts/get-projects.js) &&
  project=$(echo "$folders" |
           fzf-tmux -d $(( 2 + $(wc -l <<< "$branches") )) +m) &&
  code $(echo "$HOME/d/$project")
}

pbr() {
  local branches branch
  branches=$(git branch --all | grep -v HEAD) &&
  branch=$(echo "$branches" |
           fzf-tmux -d $(( 2 + $(wc -l <<< "$branches") )) +m) &&
  echo "$branch" | sed "s/.* //" | sed "s#remotes/[^/]*/##"
}

fbr() {
  local branches branch
  branches=$(git branch | grep -v HEAD) &&
  branch=$(echo "$branches" |
           fzf-tmux -d $(( 2 + $(wc -l <<< "$branches") )) +m) &&
  git checkout $(echo "$branch" | sed "s/.* //" | sed "s#remotes/[^/]*/##")
}

reset_amp_db() {
  local files file
  files=$(ls $HOME/d/payer)
  file=$(echo "$files" |
           fzf-tmux -d $(( 2 + $(wc -l <<< "$files") )) +m)
  (echo "DROP DATABASE IF EXISTS \"$1\" WITH (FORCE); CREATE DATABASE \"$1\";" | psql postgres) && psql "$1" < "/Users/samueldesota/d/payer/$file"
}

ops() {
  local oplist itemuuid
  oplist=$(op list items) &&
  itemuuid=$(echo "$oplist" | jq -r ".[] | [.overview.title, .uuid] | @tsv"  | fzf -d "\t" --with-nth=1 | cut -f 2) &&
  op get item "$itemuuid" | jq -rj ".details.fields[] | select(.designation == \"password\") | .value" | pbcopy
}

op_login() {
  eval $(security find-generic-password -l service -w | op signin noir-gallery.1password.com sam@noirgallery.co $(security find-generic-password -l op_secret_key -w))
}

opass() {
  op_login && ops
}

alias brew="/opt/homebrew/bin/brew"
alias brew86="arch -x86_64 /usr/local/homebrew/bin/brew"
alias zsh86="arch -x86_64 zsh"
alias 86="arch -x86_64"
alias nid="npm i -D"
alias nis="npm i -S"
alias pid="pnpm add --save-dev"
alias pis="pnpm add"
alias cbr="git branch --show-current"
alias code="code-insiders"

gpull() {
  if [ -n "$1" ]; then
    git pull origin "$1":"$1"
    return
  else
    git pull origin $(cbr)
  fi
}

gpc() {
  gpull "$1" && git checkout "$1"
}

gpush() {
  git push origin $(cbr)
}

#source /Users/samueldesota/.config/broot/launcher/bash/br

export PATH="/usr/local/homebrew/opt/openjdk@11/bin:$PATH"
#source ~/.aws-fzf
#source /Users/samueldesota/.cargo/env

ytsong () {
  youtube-dl -f bestaudio --extract-audio --audio-format mp3 -o "~/songs/%(title)s.%(ext)s" --audio-quality 0 "https://www.youtube.com/watch?v=$1"
}

gacommit () {
  git add . && git commit -m "$1"
}

gdo () {
  while true ; do
   echo -n "🔨 "
   read -n input
   printf '\033[1A\033[K'

   git add .
   git commit -m "$input"
   gpush

   echo "✅ $input"
  done
}

# pnpm
export PNPM_HOME="/Users/samueldesota/Library/pnpm"
export PATH="$PNPM_HOME:$PATH"
# pnpm endsource ${HOME}/.ghcup/env

PATH=~/.console-ninja/.bin:$PATH
[ -s "$HOME/.local/bin/env" ] && . "$HOME/.local/bin/env"
export PATH="/opt/homebrew/opt/openjdk/bin:$PATH"
export PATH="$PATH:/Applications/Tailscale.app/Contents/MacOS"

# Added by Antigravity
export PATH="/Users/sam/.antigravity/antigravity/bin:$PATH"

# bun completions
[ -s "/Users/sam/.bun/_bun" ] && source "/Users/sam/.bun/_bun"

# bun
export BUN_INSTALL="$HOME/.bun"
export PATH="$BUN_INSTALL/bin:$PATH"

alias cl="IS_SANDBOX=1 claude --dangerously-skip-permissions"
alias gcl="ANTHROPIC_BASE_URL=http://localhost:8317 ANTHROPIC_MODEL=gpt-5.4 claude --dangerously-skip-permissions --thinking-display summarized"

# Shorten zellij socket path to avoid 103-byte Unix socket limit on macOS
export ZELLIJ_SOCKET_DIR=/usr/local/var/zellij

# Added by codebase-memory-mcp install
export PATH="/Users/sam/.local/bin:$PATH"

# Machine-local secrets (not synced)
[ -f "$HOME/.env.local" ] && source "$HOME/.env.local"

# cdd: interactive directory navigator
source /Users/sam/d/cdd/cdd.sh
alias c=cdd
. "/Users/sam/.deno/env"
