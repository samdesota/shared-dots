---
name: fractal-implement
description: "Implement Tasks from a Fractal execution plan, with a review checkpoint between each Task. Use when a `plan-name-plan.md` already exists (produced by the `fractal` skill) and you want to execute it. Pass a plan name to target a specific plan (useful when running a fresh agent to implement a spec); pass a task id to run a single Task; pass both, or neither."
argument-hint: "[plan-name] [task-id]"
allowed-tools: [Read, Write, Edit, Glob, Grep, Bash, Agent, TaskCreate, TaskUpdate, TaskGet, TaskList]
---

# Fractal Implement

You are executing a Fractal plan. Each Task in the plan has Steps and Tests. Your job: implement one or more Tasks, write and run the Tests, and produce a short review at every Task boundary so the user can catch drift early.

## Modes

Both arguments are optional and positional: `[plan-name] [task-id]`.

- `/fractal-implement` — infer the plan from context; run remaining incomplete Tasks autonomously with a review between each.
- `/fractal-implement N` (numeric only) — infer the plan; implement exactly Task N, then stop.
- `/fractal-implement <plan-name>` (non-numeric) — target the named plan; run remaining Tasks autonomously.
- `/fractal-implement <plan-name> N` — target the named plan; implement exactly Task N, then stop.

`<plan-name>` may be the slug (e.g. `user-auth-rewrite`), the full dated directory name (e.g. `2026-04-25-user-auth-rewrite`), or a path to the plan dir or plan file. Match leniently.

Single-task mode (a task id was given) always stops after the review. No-task-id mode runs autonomously across remaining Tasks until something requires checking in.

## Setup

1. Find the plan.
   - If `<plan-name>` was given: resolve it under `docs/fractal/`. Try exact slug, then dated-dir name, then a path. If nothing matches, stop and tell the user.
   - Otherwise: glob `docs/fractal/*/[plan-name]-plan.md`. If exactly one matches, use it. If multiple, ask the user which one.
2. Show the plan doc using the `show_file` skill so the user can follow along.
3. Read the matching Spec doc (`[plan-name]-spec.md`) once, fully. The Spec is the source of intent — Tasks are derived from it.
4. Determine which Tasks remain. A Task is done if it has a `**Status:** done` line at the bottom of its block.
5. Create a harness Task per remaining plan Task so progress is visible. Mark the first as `in_progress`.

## Per Task

1. Re-read the Task block (Steps, Tests, Depends on). If a dependency isn't done, stop and tell the user.
2. **Implement the Steps.** Write the code.
3. **Write the Tests** listed in the Task. Every test the Task names must exist before you move on.
4. **Run the Tests.** All listed unit and integration tests must pass. For Manual tests, perform them yourself if possible (run the app, hit the endpoint, etc.) — otherwise tell the user exactly what to verify.
5. **Produce the review block** (see below).
6. If review passes: add `**Status:** done` to the bottom of the Task block in the plan doc, mark the harness Task completed.
7. Decide: proceed to next Task / stop and check in.

## The review block

After every Task, output exactly this shape:

```
Task N review:
- Steps: <done as written, or: deviated — brief description>
- Tests: <test names — green / red / missing>
- Decision: proceeding → Task N+1  /  checking in: <one-sentence reason>
```

**When to check in vs. proceed.** Use your judgment. The defaults:

- Tests not all green, or a listed Test wasn't written → **check in.**
- You deviated from Steps in a way that changes behavior, scope, or future Tasks → **check in.**
- You discovered something that makes a later Task wrong, redundant, or missing → **check in.**
- Minor deviations that don't change behavior (renamed a helper, split a function differently, picked a slightly different file location) → note in the review and **proceed.**

When genuinely uncertain, check in. The cost of confirming is one line from the user; the cost of silent drift compounds.

In single-task mode (`/fractal-implement N`), always stop after the review regardless of outcome — the user is the next reviewer.

## Rules

- **Tests are not optional.** Every Task lists them; write them; run them. If a Task somehow lists no tests, stop and tell the user — the plan is malformed.
- **Don't edit the plan beyond marking Status.** If a Task no longer fits reality, surface that in a check-in and let the user decide. Don't silently rewrite Tasks.
- **Don't start the next Task before the current one's tests are green.** This is the whole point.
- **One Task at a time.** Even in autonomous mode, finish (implement + test + review + mark done) before touching the next.
- **Keep the plan doc visible.** Use the `show_file` skill to make sure the user can see the doc you're working from.
