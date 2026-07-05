# BadmintonApp

Monorepo for a junior badminton player's training tooling.

## Projects

| Path | What | PROJECT_TYPE | Tests |
|---|---|---|---|
| `badminton_flutter/` | Flutter training-log app (sessions, techniques, tournaments, profile) | flutter | `flutter test` |
| `badminton_track/` | Python CV + local-LLM video analysis tool (planned — see `ideas/use-cases/badmintontrack-12.md`) | python-cli | `pytest` |

## Workflow

Ideas flow through `/intake` → `/research` → `/plan` → `/tdd`
(skills in `.claude/skills/`). Live docs: `ideas/pool.md`, `ideas/use-cases/`,
`research/`, `backlog/tasks/`, `backlog/done/`, `UPDATES.md`.

## Conventions & gotchas

- Video footage is of a minor: `videos/`, `data/`, `output/` under
  `badminton_track/` stay gitignored; no cloud AI APIs — LLM work is local
  (Ollama) only.
- Ultralytics model tag is `yolo11n.pt` (YOLO11), not `yolov11n.pt`.
- Only court-plane points (feet) may be projected through the court homography.
