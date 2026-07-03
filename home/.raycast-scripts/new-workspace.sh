#!/bin/bash

# Required parameters:
# @raycast.schemaVersion 1
# @raycast.title New Workspace
# @raycast.mode silent

# Optional parameters:
# @raycast.icon 🪟
# @raycast.argument1 { "type": "text", "placeholder": "Window name" }
# @raycast.packageName Window Namer

NAME="$1"

open -na "Vivaldi" --args --profile-directory="Profile 1" --new-window
sleep 0.5
~/.local/bin/bar name-window "$NAME"
~/.local/bin/bar fullscreen
