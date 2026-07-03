# Zellij Terminal Management

I use Zellij as my terminal multiplexer. Claude sessions typically run inside Zellij panes.

## Key Operations

- **List panes:** `zellij action list-panes --json --all` (current session) or `zellij -s <session> action list-panes --json --all` (other session)
- **Read pane output:** `zellij action dump-screen -p terminal_<id>` (viewport) or `--full` (full scrollback)
- **Send Ctrl+C:** `zellij action send-keys -p terminal_<id> "Ctrl c"`
- **Type into pane:** `zellij action write-chars -p terminal_<id> $'command\n'`
- **Focus pane:** `zellij action focus-pane-id terminal_<id>`
- **New pane:** `zellij action new-pane` (or `--direction right|down`)
- **New tab:** `zellij action new-tab`
- **List sessions:** `zellij list-sessions`

All commands accept `-p terminal_<id>` for pane targeting and `-s <session>` for cross-session targeting.

## When to Use

- **Restarting dev servers:** Use `list-panes` to find the pane running the dev server (look at `pane_command`), then `send-keys "Ctrl c"` + `write-chars` to restart it. Do not assume which pane it is -- check first.
- **Checking terminal logs:** Use `dump-screen` to read the output of other panes. Use `--full` for scrollback history.
- **Opening new panes/tabs:** When I ask to open a new terminal, pane, or tab, use the Zellij CLI.
