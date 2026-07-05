# Skill: audit

Verify that the project's declared design still matches the actual code.
Catches documentation rot, architecture drift, and dead code paths that other
skills miss: /next verifies roadmap statuses; /audit verifies design claims.

## When to use

- After a use-case's task chain completes
- Periodically (weekly) on an actively developed project
- Whenever docs and behaviour feel out of sync

## Steps

### 1. Collect claims

Build a claim list from:
- README - architecture tree, design sections, command tables, port numbers
- Module docstrings and file headers - any behavioural claim
- CLAUDE.md - gotchas, commands, conventions
- ROADMAP / use-case docs marked done - files, endpoints, functions they say exist
- Config example file - every documented key

Each claim gets an ID, source location, and a concrete check.

### 2. Verify each claim against code

For each claim run the cheapest sufficient check. Specifically:
- Chokepoint invariants: if docs say all X flow through Y, grep for bypass paths
- Dead code: modules the docs describe as active - confirm live call sites exist
- Duplicated implementations: two code paths doing the same job
- Config drift: keys read by code but missing from example file, and vice versa
- Doc-to-doc consistency: ports, paths, filenames across multiple docs

### 3. Classify

- holds      - claim verified in code
- stale-doc  - code is fine, doc describes an older design
- violated   - declared invariant broken in code
- dead       - claimed-active code has no live caller
- unverifiable - claim too vague to check

### 4. Report

Output a table: claim -> source -> classification -> evidence (file:line).
Lead with violated and dead findings.

### 5. Remediate

- stale-doc: fix the docs directly in this run.
- violated / dead: do NOT silently fix code. Append to `ideas/pool.md` so the
  fix goes through intake -> plan -> tdd. If trivial (< 10 lines), offer to fix immediately.
- unverifiable: reword the claim to be checkable, or delete it.

### 6. Log

Append a ## YYYY-MM-DD entry to UPDATES.md: claims checked, breakdown by
classification, docs fixed, pool entries created.

## Args

- No args: full audit
- `--area <dir-or-doc>`: restrict to one module or doc
- `--report-only`: classify and report; touch nothing
- `--quick`: only re-check stale/violated/dead from last run plus changed files

## Quality gate

Every violated or dead finding must cite evidence (file:line). If a claim can't
be verified mechanically, classify as unverifiable rather than guessing.
