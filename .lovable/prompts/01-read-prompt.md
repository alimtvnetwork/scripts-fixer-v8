# AI Project Onboarding Protocol

> **Purpose:** This document is a mandatory onboarding sequence for any AI assistant joining this project. It ensures you internalize all specifications, rules, and conventions before writing a single line of code.

> **Rule #0:** Follow every phase sequentially. Do not skip, summarize prematurely, or assume knowledge from training data. The specs are the single source of truth.

---

## Table of Contents

1. [Phase 1 — AI Context Layer](#phase-1--ai-context-layer)
2. [Phase 2 — Deep-Dive Source Specs](#phase-2--deep-dive-source-specs-task-driven)
3. [Anti-Hallucination Contract](#anti-hallucination-contract)
4. [Memory Update Protocol](#memory-update-protocol)
5. [Completion Confirmation](#completion-confirmation)

---

## Phase 1 — AI Context Layer

**Goal:** Load the project's identity, hard rules, and institutional memory into your working context.

### Step 1.1 — Read core files in EXACT order

| Order | File | What You Learn |
|-------|------|----------------|
| 1 | `.lovable/overview.md` | Project summary, tech stack, navigation map |
| 2 | `.lovable/strictly-avoid.md` | **Hard prohibitions** — violating ANY of these is a critical failure |
| 3 | `.lovable/user-preferences` | How the human expects you to communicate and behave |
| 4 | `.lovable/memory/index.md` | Index of all institutional knowledge files |
| 5 | `.lovable/plan.md` | Current active roadmap and priorities |
| 6 | `.lovable/suggestions.md` | Pending improvement ideas (not yet approved) |

### Step 1.2 — Read EVERY file referenced in `.lovable/memory/index.md`

- If the index lists 12 files, you read 12 files. No exceptions.
- If there are subfolders, traverse them recursively.
- If a file is missing or empty, note it — do not silently skip.

### Step 1.3 — Self-check (answer these internally before continuing)

- [ ] What are the project's **CODE RED** rules?
- [ ] What naming conventions are enforced (files, folders, variables)?
- [ ] What is the error handling philosophy?
- [ ] What is the current plan and what tasks are in progress?
- [ ] What patterns/tools/approaches are **strictly forbidden**?

> ⛔ **DO NOT proceed to Phase 2 until every file above has been read and internalized.**

---

## Phase 2 — Deep-Dive Source Specs (Task-Driven)

**Goal:** Before performing any task, read the relevant source spec(s) so your work is compliant.

### Lookup Table

| If your task involves... | Read this spec folder |
|--------------------------|----------------------|
| Script 01 (VS Code) | `spec/01-install-vscode/` |
| Script 02 (Chocolatey) | `spec/02-install-package-managers/` |
| Script 03 (Node.js) | `spec/03-install-nodejs/` |
| Script 12 (Orchestrator) | `spec/12-install-all-dev-tools/` |
| Script 42 (Ollama) | `spec/42-install-ollama/` |
| Script 43 (llama.cpp) | `spec/43-install-llama-cpp/` |
| Model picker | `spec/model-picker/` |
| Shared helpers | `spec/shared/` |
| Doctor command | `spec/doctor/` |
| Audit command | `spec/audit/` |
| Database scripts | `spec/databases/` |
| Root dispatcher | `spec/root-dispatcher/` |
| Version bumping | `spec/bump-version/` |
| Release pipeline | `spec/release-pipeline/` |

### Reading order within each folder

1. `readme.md` — always first (this project uses readme.md, not 00-overview.md)
2. All other files in the folder

---

## Anti-Hallucination Contract

These rules are **absolute and non-negotiable**. Violating any of them is a critical failure.

### 1. Never Invent Rules
If a spec does not mention a rule, that rule does not exist.

### 2. Specs Override Training Data
If your pre-trained knowledge conflicts with a spec, **the spec wins**. Every time.

### 3. Cite Your Sources
When enforcing a rule, reference the **specific file and section**.

### 4. Ask When Uncertain
If a spec is ambiguous or silent on a topic, **ask the human**.

### 5. Never Merge Conventions
This project has its own conventions. Do not blend with other projects.

### 6. No Filler
Never append boilerplate. Just deliver the work.

---

## Memory Update Protocol

When you learn something new during a session:

```
New information discovered
│
├─ Is it institutional knowledge (pattern, convention, decision)?
│  └─ YES → Write to `.lovable/memory/` and update `.lovable/memory/index.md`
│
├─ Is it something that must NEVER be done?
│  └─ YES → Add to `.lovable/strictly-avoid.md`
│
├─ Is it a suggestion or improvement idea (not yet approved)?
│  └─ YES → Add to `.lovable/suggestions.md`
│
└─ None of the above → Do not persist it
```

### Critical Rules

- The memory folder is `.lovable/memory/` — **never** `.lovable/memories/`.
- When adding a new memory file, **always** update the index.
- When modifying an existing memory, preserve all other content.

---

## Completion Confirmation

After completing Phase 1, respond with:

```
✅ Onboarding complete.

- Memory files read: [X]
- Spec files available: [Y folders in spec/]

I understand:
- CODE RED rules: [list]
- Naming conventions: [summary]
- Error handling approach: [one sentence]
- Active plan: [current milestone]
- Strict avoidances: [top items]

Ready for tasks.
```

Then **stop and wait** for instructions.

---

*This prompt is version 1.0. Update it in sync with spec version changes.*
