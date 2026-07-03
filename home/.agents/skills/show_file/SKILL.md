---
name: show_file
description: Show files to the user. Prefer cloud_open_pane when available; otherwise fall back to opening files in nvim via an adjacent Zellij pane.
---

# /show_file - Show Files to the User

Show the file(s) or path the user specified in the best available UI.

## Procedure

### Step 0 - Determine what to open

- **If the user provided file path(s) as arguments**, use those.
- **If no arguments were given**, infer what to open from conversation context:
  - Files you just edited or created
  - Files the user was recently discussing or asking about
  - Files relevant to the current task (e.g. the bug being debugged, the feature being built)
  - If multiple candidates are equally likely, use `AskUserQuestion` to present the top options and let the user pick
  - If nothing is inferable at all, use the fallback method with no file

### Step 1 - Prefer `cloud_open_pane` when available

If the `cloud_open_pane` tool is available, use it to open each file directly:

```json
{
  "kind": "file",
  "path": "/absolute/path/to/file",
  "activate": true
}
```

Resolve relative paths to absolute paths before calling the tool. For multiple files, call `cloud_open_pane` once per file and activate the most important file last.

### Step 2 - Fall back to the nvim script method

If `cloud_open_pane` is not available, open the file(s) in nvim using an adjacent Zellij pane.

Resolve any relative file paths to absolute paths, then run:

```bash
bash ~/.agents/skills/show_file/open-nvim-pane.sh [file ...]
```

The script finds an adjacent nvim/shell pane in the current tab and opens
there. If none exists, it creates a vertical split pane and uses it. On
success it prints which pane was used.

## Notes

- If multiple files are given, pass them all as arguments.
- Prefer the direct file pane over terminal editor presentation whenever both are available.
