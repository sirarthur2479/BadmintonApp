# Skill: research

Search GitHub and the web for prior art on a domain, score results, and write a
structured findings doc. Adapted from ECC's search-first skill.

## When to use

Run `/research <domain>` when:
- A new domain needs prior-art coverage before implementation begins
- An existing `research/<domain>.md` is stale (>90 days old)

## Steps

### 0. Tool preflight

Confirm WebSearch and WebFetch are available. If not, note the limitation and
proceed with whatever is accessible.

### 1. Need analysis

Read the triggering use-case (`ideas/use-cases/<slug>.md`) if available.
Identify: what problem in this domain needs solving, what constraints exist
(language, licence, size/perf requirements).

### 2. Parallel search

Spawn parallel searches across:
- GitHub: `site:github.com <domain> <keywords> stars:>100`
- GitHub trending / awesome lists for the domain
- npm / PyPI / pkg.go.dev (match project language from CLAUDE.md `PROJECT_TYPE`)
- Web: recent blog posts or benchmarks comparing solutions
- Academic / HN / Reddit if domain is research-heavy (e.g. memory, personality)

Collect at minimum 8 candidate repos/libs, aim for 15.

### 3. Score candidates

For each candidate score 1-5 on:
| Dimension | Weight |
|---|---|
| Functionality fit | 30% |
| Maintenance (last commit, open issues) | 20% |
| Community (stars, forks, contributors) | 20% |
| Documentation quality | 15% |
| Licence compatibility | 10% |
| Dependency footprint | 5% |

Compute weighted score. Keep top 8.

### 4. Decide per candidate

For each top candidate: adopt / extend / build-on-top / skip.
- Adopt: fits well enough to use directly
- Extend: good core, needs a wrapper or plugin
- Build-on-top: provides a foundation, significant custom work required
- Skip: too heavy, wrong licence, abandoned

### 5. Write findings doc

Write `research/<domain>.md` using `research/templates/_domain.md`.
Include the scoring table, per-candidate decision, and a final recommendation.

### 6. Output

Research complete: research/<domain>.md
Recommended approach: <adopt X | extend Y | build Z>
Next: run /plan <use-case-slug> to convert findings into backlog tasks

## Args

- `<domain>`: required. E.g. `memory`, `tts`, `llm`, `personality`, `avatar`
- `--force`: re-run even if a recent doc exists

## Quality gate

Do not write a findings doc with fewer than 5 evaluated candidates unless the
domain is genuinely narrow. If search returns thin results, state that explicitly
in the doc and note what was searched.
