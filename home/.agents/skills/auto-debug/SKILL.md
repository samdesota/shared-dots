---
name: auto-debug
description: "Autonomous debugging - hypothesis/instrument/evaluate/fix loop. Use when the user wants the agent to solve a bug independently, when a problem should be solvable without hand-holding, or when systematic instrumentation is needed to find root cause."
argument-hint: <description of the bug or unexpected behavior>
allowed-tools: [Read, Write, Edit, Glob, Grep, Bash, Agent, TaskCreate, TaskUpdate, TaskGet, TaskList, AskUserQuestion]
---

# Autonomous Debugging

You are running an autonomous debugging session. The user believes this problem is solvable by a capable agent working independently — your job is to prove them right by being methodical, not by guessing.

**The bug or problem:** $ARGUMENTS

## Phase 0: Instrument Assessment

**Before you touch the bug, figure out how you'll know when it's fixed.**

This is the most important phase. An agent that can't observe the bug can't fix it reliably. You need to answer three questions:

1. **How will I reproduce the bug?** (run a test, hit an endpoint, execute a script, check browser behavior, etc.)
2. **How will I observe what's happening?** (logs, test output, console, network requests, debugger, etc.)
3. **How will I verify my fix works?** (same as #1, or a new test, or both)

### What to do

1. Investigate the project to understand what's available: test frameworks, dev servers, build tools, logging, REPL access, browser tools, etc.
2. Try to reproduce the bug right now using whatever tools you have. If you can't reproduce it, that's critical information.
3. **Report to the user** in this format:

```
## Debugging Plan

**Bug:** [one-sentence summary of what's wrong]

**Reproduce:** [exact command or steps to trigger the bug]
**Observe:** [how you'll see what's happening — logs, test output, etc.]
**Verify:** [how you'll confirm the fix works]

**Gaps:** [anything you can't do — e.g., "no way to test this in isolation", "need access to X"]
```

4. If there are gaps — tools you need but don't have, access you're missing, reproduction steps that require the user — **ask now**. Don't discover this mid-fix.
5. Wait for the user to confirm the plan before proceeding. If they provide additional tools or context, update your plan.

**Do NOT skip this phase.** The whole point of this skill is that you establish your feedback loop before you start experimenting. If you can't observe the bug, you can't debug it — you can only guess.

## Phase 1: The Loop

Once your plan is confirmed, run the hypothesis-instrument-evaluate-fix loop. Create a task for each iteration so the user can track your progress.

### Each iteration

```
┌─────────────┐
│  Hypothesize │ ← What do you think is causing the bug? Be specific.
└──────┬──────┘
       │
       v
┌─────────────┐
│  Instrument  │ ← Add logging, write a test, narrow the scope. Make the
└──────┬──────┘   hypothesis testable. Don't change behavior yet.
       │
       v
┌─────────────┐
│  Evaluate    │ ← Run the reproduction. Read the output. Was your
└──────┬──────┘   hypothesis correct, wrong, or partially right?
       │
       v
┌─────────────┐
│  Fix or Loop │ ← If you found the cause: fix it, then verify.
└─────────────┘   If not: form a new hypothesis based on what you learned.
```

### Rules for the loop

- **One hypothesis at a time.** Don't shotgun three changes and hope one works.
- **Instrument before you fix.** If you haven't added observability that confirms your hypothesis, you're guessing. The instrumentation step is what separates this from "try random stuff."
- **Log what you learn.** After each evaluation, write down what you now know that you didn't before. This prevents you from going in circles.
- **Clean up instrumentation.** After each iteration, remove debug logging/scaffolding you added. Keep the workspace clean for the next iteration.
- **Three strikes rule.** If three hypotheses have been wrong, stop and reassess. Re-read error output from scratch. Consider whether your mental model of the system is wrong, not just your guess about the bug. Share your findings with the user and ask if they have context you're missing.

### Instrumenting effectively

Good instrumentation answers a specific question:

| Question | Instrumentation |
|----------|----------------|
| "Is this function being called?" | Add a log at the entry point |
| "What value does X have here?" | Log the value before the problematic line |
| "Is this the right code path?" | Log at each branch of a conditional |
| "Does this work in isolation?" | Write a minimal test or script that calls just this function |
| "Is the input wrong or the processing wrong?" | Log both input and output |
| "Is this a timing issue?" | Add timestamps to logs |

Bad instrumentation: adding `console.log("here")` everywhere. That's not a hypothesis — it's wandering.

## Phase 2: Verify and Clean Up

Once you believe you've fixed the bug:

1. **Remove all debug instrumentation** (logging, test scaffolding, temporary scripts).
2. **Run the reproduction from Phase 0.** Does the bug still occur?
3. **Run the existing test suite** (if one exists). Did you break anything else?
4. **Tell the user what you found and what you changed.** Be specific:
   - What was the root cause?
   - What did you change to fix it?
   - How did you verify it?

## Anti-patterns

These are signs you've left the process:

- **Fixing without instrumenting.** You read the code, thought "ah, this must be it," and changed it. Maybe you're right — but you don't *know* you're right. Instrument first.
- **Changing multiple things at once.** Now you don't know which change fixed it (or if you introduced a new bug).
- **Ignoring evaluation results.** Your instrumentation showed X but you decided to try Y anyway. Why did you bother instrumenting?
- **Not reproducing first.** You went straight to reading code. How will you know when it's fixed?
- **Cargo-culting a fix.** You found a StackOverflow answer or a similar fix elsewhere and applied it without understanding why it works for *this* bug.
