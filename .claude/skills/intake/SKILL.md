# Skill: intake

Convert a free-form idea into a structured use-case, research it, plan it, and start
implementation - fully automated from pool entry to first TDD task.

## When to use

Run `/intake` when you want to pull the next piece of work end-to-end:
- Promotes an idea from `ideas/pool.md` or `ROADMAP.md` all the way to running `/tdd`
- Only pauses when a genuine decision is needed (multiple ideas to choose from, or a
  use-case draft that has an unresolvable open question)

## Steps

### 1. Scan for work

Read both sources in parallel:
- `ideas/pool.md` - entries without done and without in-progress
- `ROADMAP.md` - rows with status ready that have no corresponding use-cases file yet

Build a single list of unprocessed items from both sources, newest-first.

In-progress check: if any pool/ROADMAP entry is in progress, look up its open tasks
in `backlog/tasks/`. If unfinished tasks exist, offer to resume first.

Auto-select rule:
- If exactly 1 unprocessed item exists -> proceed automatically
- If 2-3 items exist -> list them and ask the owner to pick one
- If more than 3 -> show the top 3 and ask the owner to pick

### 2. Extract use-case

From the selected idea, write `ideas/use-cases/<slug>.md` covering:
problem / target users / desired outcome / constraints / open questions /
implementation sketch / relevant domains.

Only pause to ask the owner if an open question is a genuine blocker.
Mark the pool.md entry or ROADMAP row as in progress.

### 3. Identify domains

List which research domains are relevant (e.g. llm, memory, tts, tools, personality).

For each domain:
- Check if `research/<domain>.md` exists and was written within the last 90 days.
- If missing or stale -> trigger `/research <domain>`. Run all missing domains in parallel.
- If all docs are current -> skip research, proceed to step 4.

### 4. Plan

Once all required research docs exist, automatically invoke `/plan <slug>`.
Do not print "Next: run /plan" - just run it.

### 5. Start TDD

After `/plan` completes, automatically invoke `/tdd TASK-NNN` for the first task.
Do not print "Next: run /tdd" - just run it.

### 6. Cleanup

- Update the pool.md entry or ROADMAP row to in progress (TASK-NNN -> TASK-MMM)
- Update `ideas/use-cases/<slug>.md` status to planned (TASK-NNN -> TASK-MMM)

Do not mark the idea done here - /tdd does that when the last task completes.

## Pause rules

| Situation | Action |
|-----------|--------|
| Multiple unprocessed ideas | Ask owner to pick |
| Use-case has open question that blocks implementation | Ask 2-3 targeted questions |
| Research returns < 5 candidates (narrow domain) | Note it, continue |
| Everything else | Proceed automatically |

## Args

- No args: auto-select if 1 idea, otherwise prompt
- "<idea title or keyword>": match the closest pool or roadmap entry
- "from idea pool": restrict scan to `ideas/pool.md` only
- "from roadmap": restrict scan to `ROADMAP.md` only

## Quality gate

Do not write a use-case with no clear desired outcome. If the idea is too vague,
ask 2-3 targeted questions before writing the doc.
