# Skill: plan

Convert research findings + a use-case into an ordered backlog of tasks, then
immediately hand off to `/tdd` for the first task.

## When to use

Run `/plan <use-case-slug>` after research docs exist for all relevant domains.
Normally invoked automatically by `/intake` - can also be run standalone.

## Steps

### 1. Load context

Read:
- `ideas/use-cases/<slug>.md` - desired outcome, constraints, open questions
- `research/<domain>.md` for each domain listed in the use-case

If any open questions are implementation blockers, surface them before continuing.

### 2. Derive tasks

From the research decisions (adopt / extend / build-on-top / skip):
- One task per discrete deliverable
- Each task maps to a single domain or module
- No hidden cross-dependencies
- If a task would take more than 2 days, split it

### 3. Order by priority

Score each task on:
| Axis | Question |
|---|---|
| Value | How directly does it unlock the use-case outcome? |
| Risk | How uncertain is the implementation? |
| Dependency | Must another task land first? |
| Effort | S / M / L |

Ordering rule: highest (value/effort ratio) first; tasks that unblock others before
tasks that depend on them; spikes before high-risk implementations.

### 4. Write task files

Scan both `backlog/tasks/` AND `backlog/done/` for the highest existing TASK-NNN.
Increment from there - never re-use a number.

For each task write `backlog/tasks/TASK-<NNN>-<slug>.md` with this exact header:

# TASK-NNN - <title>

**Use case:** [ideas/use-cases/<slug>.md](../../ideas/use-cases/<slug>.md)
**Research:** [research/<domain>.md](../../research/<domain>.md)
**Depends on:** TASK-NNN, TASK-MMM   (or - if none)
**Effort:** S | M | L
**Risk:** low | medium | high
**Status:** todo

Required body sections:
- Goal - one paragraph
- Acceptance criteria - testable, specific
- Test plan - list of test names that must be RED before implementation
- Implementation plan - step-by-step with file paths and function signatures

### 5. Hand off to TDD

After writing all task files:
1. Update use-case status to planned (TASK-NNN -> TASK-MMM)
2. Print the task summary
3. Immediately invoke `/tdd TASK-NNN` for the first task

## Args

- `<use-case-slug>`: required
- `--dry-run`: print task list without writing files or triggering /tdd
- `--no-tdd`: write task files but do not auto-invoke /tdd

## Quality gate

Do not write tasks without testable acceptance criteria.
Do not skip the implementation plan.
