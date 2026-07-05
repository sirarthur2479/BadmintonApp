# Skill: next

Read the project roadmap, apply dependency and scoring logic, and recommend
the single most logical next item to work on.

## When to use

Run `/next` when you want a reasoned recommendation for what to build next.
Works from any project with a ROADMAP.md in the project root.

## Steps

### 0. Check in-flight work first

Scan `backlog/tasks/TASK-*.md` for Status: in-progress or Status: todo.
An in-progress task is almost always the right next - recommend resuming it before
any new roadmap item. Also read `ideas/pool.md` if present.

### 1. Load roadmap

Read ROADMAP.md. Extract each item: ID, title, area, status, scores
(Effort/Compatibility/Impact/Risk 1-5), prerequisites, estimated time.

### 2. Verify current state against codebase

For each non-done item, grep for key identifiers, check git log, look for tests.
Classify as: confirmed <status>, likely done, partially done, or stale ready.

Output a verification summary and ask owner to confirm discrepancies before scoring.

### 3. Filter candidates

Remove: done items, needs-design items, items with unmet prerequisites.
Flag in-progress items and ask: "Continue that, or pick something new?"

### 4. Score remaining candidates

priority = (impact x compatibility) / (effort x risk)

Tiebreakers: unblocks most others -> lower effort -> lower risk.

### 5. Recommend

Output ranked top 3, then a single clear recommendation:

  Next: #N - Title

  Why now:
  - Score: X.X
  - Unblocks: #X, #Y

  Estimated time: N days
  To start: run /plan <slug> or /tdd TASK-XXX if a task already exists.

  Also worth considering:
    #M - Title (score X.X)
    #P - Title (score X.X)

### 6. Update live docs

Fix stale ROADMAP.md statuses. Append changed items to UPDATES.md.

### 7. Offer to act

Ask: "Start on #N now? I can run /intake to create a use-case and backlog tasks."
If yes -> run `/intake "<feature title>"`.

## Args

- No args: recommend from full roadmap
- `--area <name>`: restrict to one area
- `--quick`: prefer effort <= 2 regardless of score
- `--unblock`: prefer items that unblock the most others
- `--list`: show full scored table without recommending

## Quality gate

Do not recommend a needs-design item as next - surface it as a blocker instead.
