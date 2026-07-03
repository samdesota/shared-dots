#!/bin/bash

# Required parameters:
# @raycast.schemaVersion 1
# @raycast.title Rename Window
# @raycast.mode silent

# Optional parameters:
# @raycast.icon ✏️
# @raycast.argument1 { "type": "text", "placeholder": "New name" }
# @raycast.packageName Window Namer

~/.local/bin/bar name-window "$1"
