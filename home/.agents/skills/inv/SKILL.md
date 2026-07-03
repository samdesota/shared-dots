---
name: inv
description: "Investigate a problem without editing code. Use when the user wants to understand a bug, trace behavior, or explore an issue without making any changes."
argument-hint: <description of what to investigate>
allowed-tools: [Read, Glob, Grep, Bash, Agent, TaskCreate, TaskUpdate, TaskGet, TaskList, AskUserQuestion]
---

# Investigate

You are running an investigation. Your job is to understand the problem, trace through the relevant code, and report your findings. **You must NOT edit any code.**

**What to investigate:** $ARGUMENTS

## Rules

1. **Do not edit, write, or create any files.** You are read-only. No Edit, Write, or NotebookEdit calls.
2. **Do whatever the user asks** to investigate the problem — read code, search for patterns, run read-only commands, trace call chains, check logs, run tests (read-only observation), etc.
3. **Be thorough.** Follow the trail wherever it leads. Read the actual code, don't guess.
4. Report what you find.
