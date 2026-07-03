---
name: fractal
description: "Fractal Engineering - grow a seed idea through progressive levels of detail into a spec and execution plan. Use when starting a new feature, project, or significant piece of work that needs planning before implementation."
argument-hint: <seed idea>
allowed-tools: [Read, Write, Edit, Glob, Grep, Bash, Agent, TaskCreate, TaskUpdate, TaskGet, TaskList]
---

# Fractal Engineering

You are running the Fractal Engineering process. This is a disciplined planning methodology that grows a small idea into an actionable spec through progressive expansion. The key principle: **compress before you expand**. At each stage, the plan must earn its length — if it can't fit the constraints, you don't understand the problem well enough yet.

## The Stages

1. **Seed** — A clear, one-or-two-sentence framing of the thing we're trying to address. Starts from the user's input ($ARGUMENTS); stay close to it, but sharpen the wording if it's vague or unclear. Doesn't have to be a verbatim copy.
2. **Solution** — A distilled bulleted list of the key architectural decisions. The output of a back-and-forth conversation about how this works, not a transcript of it. Wrong decisions should jump out.
3. **Spec** — Enough detail to hand off to an implementation agent. Interfaces, components, edge cases, dependencies, diagrams.
4. **Plan** — A sequence of Tasks. Each Task names the work and the verification.

## Documents

All documents live in `docs/fractal/YYYY-MM-DD-plan-name/` where the date is today and `plan-name` is a short kebab-case slug derived from the Seed. Create the directory at setup.

- **Spec document** (`plan-name-spec.md`): Contains the Seed, Solution, and Spec. Grows as you progress through stages.
- **Execution document** (`plan-name-plan.md`): Contains only the Plan. Created at the final stage.

## Process

### Setup

1. Create tasks for each stage: Seed, Solution, Spec, Plan. Mark Seed as in_progress immediately.
2. Derive a short kebab-case `plan-name` from the Seed. Create the directory `docs/fractal/YYYY-MM-DD-plan-name/`.
3. Write the initial `plan-name-spec.md` with just the Seed section.
4. Use the `show_file` skill to show `plan-name-spec.md` to the user. The skill uses the best available UI and falls back to an adjacent nvim pane.

### At Each Stage

**Research first.** Before writing anything, determine what you need to know. Use the Agent tool with subagents to research the codebase, explore architecture, check existing patterns, or investigate technical questions. Subagents keep research details out of your context — have them **summarize findings concisely** (instruct them: "report in under 200 words" or similar). Only research what's relevant to the current stage.

**Ask when uncertain.** If you're unsure about requirements, constraints, or the user's intent, ask before writing. Short, specific questions — not a list of 10 things. It's better to ask one good question than to guess and bury the guess in text.

**Write the stage.** Add the new section to `plan-name-spec.md` (or create `plan-name-plan.md` for the Plan stage). The previous stage's text should still be recognizable — you're expanding, not rewriting.

**Show the user.** After writing, make sure the document is visible to the user — use the `show_file` skill to open it if it isn't already. The user will read it there.

**Wait for approval.** Explicitly tell the user which stage you've completed and ask if they want to adjust before moving on. Do NOT proceed to the next stage without the user's go-ahead. Mark the current task as completed and the next as in_progress only after approval.

### Stage-Specific Guidance

**Solution (key decisions):**
- A distilled bulleted list of the key architectural decisions for how this will be built. Nothing else.
- Decisions only — not concerns, not open questions, not implementation details. Resolve the questions in conversation first; the Solution captures the answers.
- One bullet per decision. Name the choice, not the rationale. Sub-bullets only when a single decision has 2–3 sub-parts that hang together.
- The Solution is the *output* of the back-and-forth on this stage (which may include sketches or diagrams shared in conversation). It is not a transcript.
- A good Solution is short. If it runs past ~10 lines, you're drifting toward Spec — pull back.

Example (seed: "build a feature flag service for our backend"):

```
- Storage: Postgres table keyed on (flag_name, environment). Audit history via logical replication, not a separate table.
- Evaluation: in-process SDK polls control plane every 10s; falls back to last-known cache on network error.
- Targeting: ordered rule list per flag — user-id match, percentage rollout, arbitrary attribute match.
- Admin UI: separate Next.js app; reads/writes via the same gRPC API the SDK uses.
- Auth: SDK uses signed JWT from existing auth service; admin UI uses SSO.
```

**Anti-patterns:**
- Don't write the Spec in bullet form. Details belong in the Spec stage.
- Don't list concerns or open questions — resolve them in conversation, then write the answer.
- Don't justify each bullet with sub-bullets of rationale. If it matters, it surfaces in conversation; the Spec carries detail.

**Spec (detailed):**
- Now you can use structure: sections, lists, code snippets, interface definitions.
- Must be complete enough that an implementation agent can work from it without asking clarifying questions.
- Include: what components exist, how they connect, what the edge cases are, what dependencies are needed.
- Exclude: implementation steps, file-by-file breakdowns, code to copy-paste. The implementer decides how to build it.

**Plan (execution):**
- Lives in a separate `plan-name-plan.md` file in the same directory. Show it to the user using the `show_file` skill.
- The Plan is a sequence of **vertical-slice Tasks**. Each Task names a user-visible behavior, the full-stack work needed to ship it, and the verification.
- A good Plan starts with the smallest useful end-to-end slice, then adds later vertical slices to deepen, broaden, or polish the behavior.
- For UI work, include the backend endpoint, persistence, frontend surface, and wiring for that feature in the same Task whenever they are needed for the slice to work.
- Avoid horizontal Tasks like "build all API endpoints" or "create the UI shell" unless they are genuinely standalone infrastructure with their own verification.

Every Task uses this template:

```
## Task N: <short title>

<1-2 sentences: what this task accomplishes and why it stands alone>

**Steps**
- <concrete bullet — file, component, or behavior>
- <bullet>

**Tests**
- E2E: <user-flow test for the slice, if applicable>
- E2E: ...
- Unit: <focused test for logic, edge case, or contract, if useful>
- Unit: ...
- Human: <only what a person must verify, if automation cannot cover it>

**Maintainability**
- <risk of a clean-code violation in this Task, and how to avoid it>
- ...

**Depends on:** Task M (or: none)
```

**Sizing.** A Task is sized so its vertical slice can be implemented, tested, and shipped before starting the next Task. If a full slice is too large, pare the first Task down to a minimal end-to-end version and move enhancements into later vertical-slice Tasks.

**Tests required.** Every Task has at least one test. Prefer e2e tests centered on the user flow for the slice. Add as many unit tests as needed for important logic, edge cases, or backend contracts that e2e tests cannot cover well. Write each test as its own bullet, repeating labels as needed (`- Unit: ...`, `- Unit: ...`) instead of grouping multiple tests into one bullet. Do not force exactly one E2E, one Unit, and one Human check; omit categories that do not apply. Human verification is only required when something is genuinely not automatable, such as visual polish or third-party UIs. No "we'll test at the end" Tasks.

**Maintainability required.** Every Task has 3-5 Maintainability notes for the implementation agent. Each note names a likely risk for that Task and how to avoid it. Consider small focused modules, functions, and components that follow SRP; avoiding large 1000+ line files; DRY; and avoiding duplicated utility logic.

**Anti-patterns.**
- Don't write phases ("Phase 1: foundations") — write Tasks.
- Don't split a feature into separate backend-only and frontend-only Tasks when the user-visible behavior depends on both.
- Don't defer the first working end-to-end path until after multiple preparatory Tasks unless a dependency truly cannot be avoided.
- Don't write bare acceptance criteria — every check belongs to a Task.

## Rules

- **No verbosity.** Every sentence must earn its place. If a stage feels padded, cut it.
- **No guessing.** If you need information, research it or ask. Don't speculate and bury assumptions.
- **No skipping ahead.** Each stage builds on the last. Don't jump to Spec detail in the Solution.
- **Subagents for research.** Use the Agent tool to delegate codebase exploration, technical investigation, or any research that would pollute your context. Instruct subagents to return concise summaries.
- **One stage at a time.** Complete each stage, get approval, then move on.
