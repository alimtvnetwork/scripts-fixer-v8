# Write Memory

> **Purpose:** After completing work or at the end of a session, the AI must persist everything it learned, did, and left undone — so the next AI session can pick up seamlessly with zero context loss.
>
> **When to run:** At the end of every session, after completing a task batch, or when explicitly asked to "update memory" / "write memory" / "end memory".

---

## Table of Contents

1. [Core Principle](#core-principle)
2. [Phase 1 — Audit Current State](#phase-1--audit-current-state)
3. [Phase 2 — Update Memory Files](#phase-2--update-memory-files)
4. [Phase 3 — Update Plans & Suggestions](#phase-3--update-plans--suggestions)
5. [Phase 4 — Update Issues](#phase-4--update-issues)
6. [Phase 5 — Consistency Validation](#phase-5--consistency-validation)
7. [File Naming & Structure Rules](#file-naming--structure-rules)
8. [Anti-Corruption Rules](#anti-corruption-rules)

---

## Core Principle

> **The memory system is the project's brain.** If you did something and didn't write it down, it didn't happen. If something is pending and you didn't record it, it will be lost. Write memory as if the next AI has amnesia — because it does.

---

## Phase 1 — Audit Current State

Before writing anything, take inventory. Answer these questions internally:

### What was done this session?
- [ ] List every task completed (features, fixes, refactors)
- [ ] List every file created, modified, or deleted
- [ ] List every decision made and why

### What is still pending?
- [ ] List tasks that were started but not finished
- [ ] List tasks that were discussed but not started
- [ ] List blockers or dependencies that prevented completion

### What was learned?
- [ ] New patterns or conventions discovered
- [ ] Gotchas or edge cases encountered
- [ ] User preferences expressed (explicitly or implicitly)

### What went wrong?
- [ ] Bugs encountered and their root causes
- [ ] Approaches that failed and why
- [ ] Things that should never be repeated

---

## Phase 2 — Update Memory Files

### Target: `.lovable/memory/`

This is the project's institutional knowledge. Update it based on what you audited in Phase 1.

#### Step 2.1 — Read the current index
```
Read: .lovable/memory/index.md
```
Understand what memory files already exist. Do not create duplicates.

#### Step 2.2 — Update existing memory files
For each existing memory file affected by this session's work:
- Open the file
- Add new information in the appropriate section
- Mark completed items as done (use `[x]` or `✅`)
- Preserve all existing content — **never truncate or overwrite unrelated entries**

#### Step 2.3 — Create new memory files (if needed)
If this session produced knowledge that doesn't fit any existing file:
1. Create a new file in `.lovable/memory/` using the naming convention: `xx-descriptive-name.md` (lowercase, kebab-case)
2. **Immediately update** `.lovable/memory/index.md` to include the new file

#### Step 2.4 — Update workflow state
```
Target: .lovable/memory/workflow/
```
Update workflow files to reflect:
- What phases/milestones are **done**
- What is **in progress**
- What is **next**

| Status | Marker |
|--------|--------|
| Done | `✅ Done` |
| In Progress | `🔄 In Progress` |
| Pending | `⏳ Pending` |
| Blocked | `🚫 Blocked — [reason]` |
| Avoid or Skip | `🚫 Blocked — [avoid]` |

---

## Phase 3 — Update Plans & Suggestions

### 3A — Plans
```
Target: .lovable/plan.md
```
- Update task statuses (done / in progress / pending)
- Add any new tasks discovered during this session
- If a plan item is **fully complete**, move it to a `## Completed` section at the bottom of the same file (do not delete it)
- Keep the plan file as the **single source of truth** for project roadmap

### 3B — Suggestions
```
Target: .lovable/suggestions.md
```
Maintain a **single file** for all suggestions (do not split into multiple files). Structure it as:

```markdown
## Active Suggestions

### [Suggestion Title]
- **Status:** Pending | In Review | Approved | Rejected
- **Priority:** High | Medium | Low
- **Description:** What and why
- **Added:** [date or session reference]

## Implemented Suggestions

### [Suggestion Title]
- **Implemented:** [date or session reference]
- **Notes:** Any relevant details about the implementation
```

When a suggestion is implemented:
1. Move it from `## Active Suggestions` to `## Implemented Suggestions`
2. Add implementation notes
3. Reference the relevant commit, file, or task if applicable

---

## Phase 4 — Update Issues

### 4A — Pending Issues
```
Target: .lovable/pending-issues/
```

For every **unresolved** bug or issue discovered, create or update:

**Filename:** `xx-short-description.md`

**Required structure:**
```markdown
# [Issue Title]

## Description
What is broken or unexpected.

## Root Cause
Why it happens (if known). If unknown, write "Under investigation."

## Steps to Reproduce
1. Step one
2. Step two
3. Expected vs actual behavior

## Attempted Solutions
- [ ] Approach 1 — [result]
- [ ] Approach 2 — [result]

## Priority
High | Medium | Low

## Blocked By (if applicable)
What dependency or decision is needed before this can be fixed.
```

### 4B — Solved Issues
```
Target: .lovable/solved-issues/
```

When an issue is **resolved**, move it from `pending-issues/` to `solved-issues/` and add:

```markdown
## Solution
What fixed it.

## Iteration Count
How many attempts it took.

## Learning
What we learned from this issue.

## What NOT to Repeat
Specific anti-patterns or mistakes to avoid in the future.
```

### 4C — Strictly Avoided Patterns
```
Target: .lovable/strictly-avoid.md
```

If a solved issue revealed a pattern that must **never** be used again, add it here:

```markdown
- **[Pattern Name]:** [Why it's forbidden]. See: `.lovable/solved-issues/xx-filename.md`
```

If the user explicitly said to skip or avoid a task during the session, also persist it under a memory file in `.lovable/memory/constraints/` or add it to `strictly-avoid.md` if it is a hard prohibition.

---

## Phase 5 — Consistency Validation

After all writes are complete, perform these checks:

### 5.1 — Index Integrity
Verify that **every file** in `.lovable/memory/` (including subfolders) is listed in `.lovable/memory/index.md`. If not, add it.

### 5.2 — Cross-Reference Check
- Every task marked `✅ Done` in `plan.md` should have corresponding evidence (memory update, solved issue, or code change)
- Every item in `pending-issues/` should be reflected in `plan.md` or `suggestions.md` if it's actionable
- No file should exist in both `pending-issues/` and `solved-issues/`

### 5.3 — Orphan Check
- No memory file should exist without an index entry
- No suggestion should be marked "Implemented" without evidence in the codebase
- No issue should be in `solved-issues/` without a `## Solution` section

### 5.4 — Final Confirmation

After all checks pass, respond with:

```
✅ Memory update complete.

Session Summary:
- Tasks completed: [X]
- Tasks pending: [Y]
- New memory files created: [Z]
- Issues resolved: [N]
- Issues opened: [M]
- Suggestions added: [S]
- Suggestions implemented: [T]

Files modified:
- [list every file touched during this memory update]

Inconsistencies found and fixed:
- [list any, or "None"]

The next AI session can pick up from: [describe the current state and next logical step]
```

---

## File Naming & Structure Rules

| Rule | Example |
|------|---------|
| All files use numeric prefix | `01-auth-flow.md`, `02-api-design.md` |
| Lowercase, hyphen-separated | `03-error-handling.md` ✅ / `03_Error_Handling.md` ❌ |
| Plans → single file | `.lovable/plan.md` |
| Suggestions → single file | `.lovable/suggestions.md` |
| Pending issues → one file per issue | `.lovable/pending-issues/01-login-crash.md` |
| Solved issues → one file per issue | `.lovable/solved-issues/01-login-crash.md` |
| Memory → grouped by topic | `.lovable/memory/workflow/`, `.lovable/memory/decisions/` |
| Completed plans/suggestions → `## Completed` section in same file | Do NOT create separate `completed/` folders |

### Folder Structure Reference

```
.lovable/
├── overview.md                  # Project summary
├── strictly-avoid.md            # Hard prohibitions
├── user-preferences             # Communication style
├── plan.md                      # Active roadmap (single file)
├── suggestions.md               # All suggestions (single file)
├── prompt.md                    # Index of prompts
├── prompts/
│   ├── 01-read-prompt.md        # Onboarding protocol
│   └── 02-write-prompt.md       # This file
├── memory/
│   ├── index.md                 # Index of all memory files
│   ├── workflow/                # Workflow state and progress
│   ├── constraints/             # Hard constraints
│   ├── preferences/             # User/project preferences
│   ├── features/                # Feature-specific knowledge
│   └── suggestions/             # Per-script suggestions tracker
├── pending-issues/              # Unresolved bugs/issues
└── solved-issues/               # Resolved bugs/issues
```

> ⚠️ **NEVER** create `.lovable/memories/` (with trailing `s`). The correct path is `.lovable/memory/`.

---

## Anti-Corruption Rules

1. **Never delete history** — Mark items as done, move them to completed sections. Never remove them entirely.
2. **Never overwrite blindly** — Always read a file before writing to it. Preserve existing content.
3. **Never leave orphans** — Every file must be indexed. Every reference must resolve.
4. **Never split what should be unified** — Plans and suggestions each live in ONE file. Do not fragment.
5. **Never mix states** — An issue cannot be both pending and solved. A task cannot be both done and in progress.
6. **Never skip the index update** — If you create a file in `.lovable/memory/`, update `index.md` in the same operation.
7. **Never assume the next AI knows anything** — Write as if explaining to a stranger who has only the files to go on.

Any task the user mentioned to skip or avoid → put into `.lovable/memory/constraints/` or `.lovable/strictly-avoid.md`.

---

*This prompt is version 1.0. Must stay in sync with `01-read-prompt.md`.*
