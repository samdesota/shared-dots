#!/bin/bash

echo "### Updating karabiner config ###"
cd karabiner
pnpm install
pnpm run build

echo "### Reloading hammerspoon ###"
defaults write org.hammerspoon.Hammerspoon MJConfigFile "~/.config/shared/hammerspoon/init.lua"
hs -c "hs.reload()"
