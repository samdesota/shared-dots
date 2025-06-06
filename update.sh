#!/bin/bash

set -e

echo "### Updating karabiner config ###"
cd karabiner
pnpm install
pnpm run build

echo "### Reloading hammerspoon ###"
cd ../hammerspoon
defaults write org.hammerspoon.Hammerspoon MJConfigFile "~/.config/shared/hammerspoon/init.lua"
hs -c "hs.reload()"

echo "### Installing latest codemods ###"
cd ../codemods
code --force --install-extension latest.vsix
