# Skill: tdd

Implement a backlog task using strict RED -> GREEN -> REFACTOR per vertical slice.
Adapted from glebis/claude-skills tdd-workflow.

## When to use

Run `/tdd <task-id>` to implement a single backlog task with full TDD discipline.

## Steps

### Phase 0: Setup

Read `backlog/tasks/<task-id>-*.md`. Confirm:
- Status is todo or in-progress (refuse only if done)
- Acceptance criteria are testable
- Research doc exists for the relevant domain

If status is in-progress, resume instead of restarting:
1. git log --oneline for commits matching (TASK-<id>)
2. git status for uncommitted files belonging to this task
3. Run the test suite to see what's currently RED
Announce the reconstructed state and continue. Never rewrite committed slices.

Set task status to in-progress and proceed - do not ask "ready to start?".

Test framework by PROJECT_TYPE (from CLAUDE.md):
| PROJECT_TYPE | Test command |
|---|---|
| python-* | pytest |
| ts-* / js-* | npm test or vitest |
| rust-* | cargo test |
| go-* | go test ./... |
| dotnet-* | dotnet test |
| other | ask owner |

### Phase 1: Decompose into vertical slices

Break the task into 2-5 vertical slices. A vertical slice is the thinnest cut that
delivers one testable behaviour end-to-end (not a layer, not a mock).

Print the slice list, then proceed directly to slice 1 RED.

### Phase 2-N: Per-slice RED -> GREEN -> REFACTOR

Repeat for each slice:

RED:
1. Write the test(s) for this slice only. Must compile and fail for the right reason.
2. Run the test command. Confirm failure output.
3. Commit: test(TASK-<id>): RED - <slice description>
4. Do not proceed to GREEN until RED is confirmed.

GREEN:
1. Write the minimum implementation to make the test pass.
2. Run the test command. Confirm all tests pass.
3. Commit: feat(TASK-<id>): GREEN - <slice description>

REFACTOR:
1. Clean up: remove duplication, improve naming, fix code style.
2. Run linter if configured (ruff, eslint, clippy, etc.)
3. Commit: refactor(TASK-<id>): REFACTOR - <slice description>

### Final phase: Verify + review gate

1. Run full test suite. No regressions allowed.
2. Summarise what was built, slice by slice.
3. Ask owner: "Ready to review? Any changes before PR?"
4. Set task status to done only after owner confirms.

### Completion bookkeeping

1. Move task file to `backlog/done/`.
2. Append row to UPDATES.md under today's ## YYYY-MM-DD heading.
3. If last open task for its use-case:
   - Flip pool.md / ROADMAP row to done
   - Set use-case status to done
4. Commit: chore(TASK-NNN): archive task, update status docs

### Auto-chain to next task

Scan `backlog/tasks/TASK-*.md` for Status: todo. A task is unblocked when every
dependency has Status: done or lives in backlog/done/. Pick the lowest-numbered
unblocked task and invoke `/tdd TASK-NNN` automatically.

If none found, print:
  All tasks complete for this use-case.
  Chain finished - start a fresh session.
  Everything is persisted to files. Run /intake or /next to pick up the next piece of work.

## Args

- `<task-id>`: required. E.g. TASK-001
- `--slice <n>`: resume from slice n
- `--dry-run`: plan slices only, don't write any code

## Quality gates

- RED gate: never write implementation before a failing test exists.
- No slice bundling: implement one slice at a time.
- No regressions: full suite must pass before marking done.
- Owner sign-off required before status -> done.
