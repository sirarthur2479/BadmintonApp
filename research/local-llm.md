# Research: local-llm

**Date:** 2026-07-05 / **Triggering use-case:** ../ideas/use-cases/badmintontrack-12.md

## Need summary

Module 4 of BadmintonTrack-12 needs a **fully local** LLM on an Apple Silicon Mac
(8–16 GB RAM, exact machine still an open question in the use-case) that turns a
compact JSON metrics summary (pre-computed footwork/biomech stats plus
pre-worded anomaly facts) into an encouraging, age-appropriate (~12 y/o reading
level) **Markdown coach report** with 2–3 concrete drills per finding.
Hard constraints:

- **No cloud APIs ever** — footage/data of a minor. Local inference only.
- Persona guardrails: growth-mindset tone, no body commentary, injury-safety
  wording ("check with your coach before changing technique").
- **Fail gracefully** when the LLM server isn't running — the deterministic
  metrics report must still be produced.
- Python 3.11+, minimal dependency footprint (sits beside ultralytics/mediapipe
  /opencv in `badminton_track/`).
- The LLM never does arithmetic — all stats are computed in pandas; the model
  only narrates. So the decisive capabilities are *instruction following, tone
  control and prompt-template friendliness*, not reasoning benchmarks.

Two layers evaluated: (a) serving stack, (b) model choice on 8–16 GB.

## Candidates evaluated

Scoring: functionality fit 30%, maintenance 20%, community 20%, documentation
15%, licence 10%, dependency footprint 5%. Stars/pulls and push dates for the
GitHub rows were verified live via the GitHub API on 2026-07-05; PyPI versions
verified via the PyPI JSON API. **ollama.com library pages could not be fetched
directly (proxy 403)** — model tag sizes/pulls below come from secondary 2026
sources and are marked (u) = unverified-by-primary-fetch.

| Name | Layer | Stars or pulls | Last release / push | Licence | Weighted | Decision |
|---|---|---|---|---|---|---|
| Ollama + `ollama` Python pkg | serving | 175.5k ★ (server), 10.2k ★ (python lib) | server pushed 2026-07-04; pypi `ollama` 0.6.2 (2026-04-29) | MIT | **4.90** | **adopt** |
| qwen3:8b (Qwen3-8B) | model | qwen3 heavily recommended 2026; not in top-6 pull list (u) | Qwen3 2025-04; 2507 refresh 2025-07 (u) | Apache-2.0 | **4.65** | **adopt (default)** |
| llama.cpp (`llama-server`) | serving | 119.4k ★ | pushed 2026-07-05 (rolling releases) | MIT | 4.50 | build-on-top only if Ollama ever blocks; skip for now |
| gemma3:4b / gemma4:E4B | model | gemma3 ~38.1M pulls (u) | gemma3 2025-03; Gemma 4 E-series 2026-04-02, 12B 2026-06-03 (u) | Gemma Terms of Use | 4.45 | **adopt (fallback tag)** |
| llama3.2:3b | model | ~74.5M pulls (u) | 2024-09 (superseded) | Llama Community | 3.95 | skip (older gen; gemma3:4b/qwen3:4b beat it) |
| llama-cpp-python | serving | 10.5k ★ | pypi 0.3.32 (2026-06-29) | MIT | 3.80 | skip (in-process alternative; heavy build, single maintainer) |
| phi4-mini (3.8B) | model | mid-popularity (u) | 2025-02 (u) | MIT | 3.75 | skip (CPU-friendly analytics, but dry prose for a kid-facing report) |
| mlx-lm | serving | 6.2k ★ | pypi 0.31.3 (2026-04-22); pushed 2026-06-24 | MIT | 3.60 | skip as direct dep — Ollama ≥0.19 uses MLX under the hood anyway |
| LM Studio (local server + `lmstudio` SDK) | serving | `lms` CLI 5.0k ★; app closed-source | pypi `lmstudio` 1.5.0 (2025-08) | app proprietary / SDK MIT | 3.45 | skip (GUI app dependency, weaker automation story) |
| vLLM (+ vllm-metal) | serving | 85.4k ★ | pypi 0.24.0 (2026-06-30) | Apache-2.0 | 3.45 | skip — confirmed overkill (see notes) |
| llama3.1:8b | model | ~116.5M pulls, most-pulled model (u) | 2024-07 (two generations old) | Llama Community | 3.45 | skip — **replace as use-case default** |
| qwen2.5:7b | model | high (via qwen2.5 family) (u) | 2024-09 (superseded by qwen3) | Apache-2.0 | 3.35 | skip (superseded; drop from docs in favour of qwen3) |

12 candidates evaluated (quality gate ≥5 met). Search was **not** thin on the
serving layer; on the model layer, ollama.com's own tag pages were unreachable
through the session proxy, so tag sizes/dates rely on multiple concurring
secondary sources (marked (u) above and below).

## Per-candidate notes (top 8)

### 1. Ollama + `ollama` Python package — 4.90 — adopt
- **Fit 5:** exactly the shape Module 4 needs. `pip install ollama` gives a
  typed client over the local server; `chat()` supports a `format=` parameter
  taking `'json'` **or a full JSON schema** (`JsonSchemaValue`) — verified in
  `ollama/_client.py` — with constrained decoding server-side, so a
  Pydantic-schema'd report skeleton is enforceable, not just requested. `think:
  Optional[bool]` parameter (also verified in source) turns Qwen3-style
  chain-of-thought off for fast, deterministic narration. Big 2026 development:
  **Ollama ≥0.19 (2026-03-30) runs on Apple's MLX framework on Apple Silicon**
  (announced on the Ollama blog as a preview; blog page itself 403'd through
  the proxy — corroborated by AppleInsider and multiple benchmark writeups
  reporting roughly 2x speedups) — so the "should we use MLX instead?"
  question answers itself: Ollama *is* the MLX path now, without us depending
  on `mlx-lm` directly.
- **Graceful degradation is a first-class error surface** (verified in
  `_client.py:127,144-145`): server not running raises built-in
  `ConnectionError` with a clear message; HTTP-level failures raise
  `ollama.ResponseError` with `.status_code` (404 = model not pulled). Exactly
  two `except` clauses cover the whole failure matrix.
- **Maintenance 5 / community 5:** server pushed daily (2026-07-04), 175.5k
  stars; python lib pushed 2026-06-18, 10.2k stars. Docs 4 (README + examples
  incl. a `structured-outputs.py` using `format=Model.model_json_schema()`).
  Licence MIT. Dep footprint 5: the python lib pulls only httpx + pydantic.
- Caveat: the python lib now also exposes **cloud models** (`*-cloud` tags,
  `ollama.com` host). Irrelevant if we never sign in / never use a `-cloud`
  tag, but worth a one-line guard in `coach.py` (reject model tags ending in
  `-cloud`) given the no-cloud hard requirement.

### 2. qwen3:8b — 4.65 — adopt as default model tag
- Qwen3 (April 2025, refreshed as `*-2507` instruct/thinking splits) is the
  consensus 2026 recommendation in the 7–8B class; Apache-2.0 (cleanest licence
  of the big three families). ~5.2–6 GB at Q4_K_M (u), leaving headroom on a
  16 GB Mac and workable-but-tight on 8 GB.
- Hybrid thinking: with the `ollama` lib pass `think=False` for this workload —
  a narration task gains nothing from CoT and the report generation stays fast.
- Strong instruction following and JSON/schema compliance (repeatedly cited in
  2026 structured-output writeups); good multilingual/tone control for the
  persona prompt.
- On an **8 GB** machine, use the smaller sibling `qwen3:4b-instruct-2507`
  (~2.6–3 GB (u)) — same family, same prompting, no thinking toggle needed.

### 3. llama.cpp `llama-server` — 4.50 — build-on-top only if needed; skip for now
- 119.4k stars, pushed same-day, MIT, production-grade OpenAI-compatible HTTP
  server, GBNF grammars / `json_schema` for constrained output. The sibling
  project (helperBot, see `research/local-llm-voice-chatbot-reference.md`) runs
  this exact stack successfully.
- Skipped because it moves model download, quantisation choice and server
  lifecycle onto the owner, and would add the `openai` SDK as the client dep.
  Everything it offers for this use case, Ollama wraps. Keep as the documented
  escape hatch (the coach module should talk to an abstract "chat" function so
  swapping transports later is one file).

### 4. gemma3:4b (and gemma4:E4B) — 4.45 — adopt as documented fallback tag
- gemma3:4b: ~2.5–3.3 GB at Q4 (u), 128K context, repeatedly called out as the
  best small model for *prose quality* — which matters more here than math,
  since the writing is the whole job. 38.1M pulls (u).
- **Gemma 4 E-series shipped 2026-04-02** (E2B/E4B/E12B/E27B, "effective"
  params for edge devices; E4B ≈ 6 GB RAM (u)) and a 12B on 2026-06-03; the
  `gemma4` tag exists on Ollama (u). E4B is the likely upgrade path once it has
  a few months of soak — for now gemma3:4b is the safer pinned fallback.
- Licence is the **Gemma Terms of Use** (use-policy restrictions, not
  OSI-approved) — fine for this personal tool, scored 3.

### 5. llama3.2:3b — 3.95 — skip
- Still enormously popular (~74.5M pulls (u)) and known-good at JSON
  instruction following, but it is September 2024 vintage; qwen3:4b and
  gemma3:4b beat it on quality at the same footprint in 2026 comparisons. No
  reason to prefer it for a new project except tutorial inertia.

### 6. llama-cpp-python — 3.80 — skip
- In-process bindings (10.5k ★, MIT, pypi 0.3.32 on 2026-06-29 — still
  actively released, contrary to periodic "is it dead?" chatter). Would remove
  the "server not running" failure mode entirely, which is attractive.
- Skipped because: compiled install (Metal wheel building on end-user Macs is
  the classic support burden), effectively single-maintainer with 672 open
  issues, model file management lands on us, and it lags upstream llama.cpp
  for new architectures. The graceful-degradation requirement is cheap to meet
  with Ollama anyway (two exception types).

### 7. phi4-mini — 3.75 — skip
- 3.8B, MIT licence, 128K context, the standout for CPU-only/low-RAM analytics
  work. For *this* task its prose is the weak point — 2026 roundups position it
  for analytics/reasoning-per-watt, not warm narrative. Would be the pick if
  the answer to open question 2 turned out to be "an old Intel Mac" (it isn't
  expected to be).

### 8. mlx-lm — 3.60 — skip as a direct dependency
- Apple's own LLM runner (6.2k ★, MIT, pypi 0.31.3 2026-04-22). Fastest
  single-request generation on Apple Silicon for <14B models (20–87% over
  llama.cpp in 2026 benchmarks (u)); `mlx_lm.server` exists but is explicitly
  not a production server, and structured output needs third-party glue
  (e.g. Outlines).
- Decisive point: **Ollama's Apple Silicon backend is now MLX** (preview since
  0.19, 2026-03), so we inherit the MLX speed advantage through the stack we
  already want, with none of the extra dependency or model-conversion work.

### Below the top 8 (brief)
- **LM Studio (3.45, skip):** excellent GUI + OpenAI-compatible local server +
  a real Python SDK (`lmstudio` 1.5.0), but the core app is proprietary and a
  GUI-app dependency automates poorly for a CLI tool run by a parent/coach.
- **vLLM (3.45, skip — overkill confirmed):** native macOS support is CPU-only
  and experimental (~20–30x slower than llama.cpp Metal per 2026 comparisons
  (u)). A community `vllm-project/vllm-metal` plugin appeared in 2026 (Docker-
  contributed) and is improving fast, but it targets serving throughput —
  batch-serving infrastructure for a tool that makes one LLM call per analysed
  video. Wrong shape for this project.
- **llama3.1:8b (3.45, skip):** the current use-case default. Most-pulled model
  on Ollama (~116.5M (u)) but July-2024 vintage, two generations behind, larger
  than the better qwen3/gemma3 options, Llama Community licence. **The
  use-case default should be updated.**
- **qwen2.5:7b (3.35, skip):** superseded by qwen3 across the board; drop from
  the docs rather than carry it as an alternative.

## Recommendation

**Serving stack: adopt Ollama + the `ollama` Python package** (exactly as the
use-case already specifies — this research confirms the choice and strengthens
it: since March 2026 Ollama runs on MLX on Apple Silicon, so it is now also the
fast path, not just the convenient one). No LiteLLM, no OpenAI SDK, no second
backend.

**Model tags** (put in `config.yaml`, not hardcoded):

- **Default: `qwen3:8b`** — best quality/size/licence balance for a 16 GB Mac;
  call with `think=False`.
- **Fallback (8 GB Macs / lighter): `gemma3:4b`** (alternatively
  `qwen3:4b-instruct-2507` to stay in one family). Document both; pick by the
  answer to use-case open question 2.
- **Update the use-case:** replace the `llama3.1:8b` default and the
  `qwen2.5:7b` alternative in `ideas/use-cases/badmintontrack-12.md` Module 4 —
  both are 2024-generation tags now.
- Guard: refuse any configured tag ending in `-cloud` (the `ollama` lib can
  reach Ollama's cloud models; hard privacy requirement says never).

### Persona guardrails — how

1. **Layered prompt, stable-prefix ordering** (reuse the verified lesson from
   `research/local-llm-voice-chatbot-reference.md` §7): one fixed system prompt
   containing persona + rules + drill vocabulary, byte-identical across runs so
   Ollama's prefix cache reuses it; the per-run metrics JSON goes last, as the
   user message. Rules stated as behaviours, not vibes:
   - growth-mindset framing ("yet", effort-focused praise, mistakes as data);
   - **no comments about body, weight, height or appearance** — only movement
     and technique;
   - every joint-angle finding must end with the safety line: *"Check this with
     your coach before changing your technique."*;
   - 2–3 concrete drills per finding, chosen from the drill list in the prompt;
   - reading level ~12 years old, short sentences, no jargon without a gloss;
   - never invent numbers — only restate facts given in the JSON.
2. **Structured output for the skeleton, Python for the Markdown.** Ask for the
   report as a Pydantic-schema'd object (sections: highlights, findings each
   with `fact`, `why_it_matters`, `drills[2..3]`, `safety_note`,
   encouragement close) via `format=CoachReport.model_json_schema()`, then
   render Markdown deterministically in `coach.py`. This turns two guardrails
   (safety line present, drill count 2–3) into schema constraints instead of
   hopes, and makes the output mergeable with the Flutter app's Markdown
   structure.
3. **Post-generation lint** (cheap, deterministic): regex screen for a small
   banned-term list (body-commentary words) and verify each biomech finding's
   `safety_note` is non-empty; on violation, retry once with the violation
   named, else fall back to the metrics-only report. Temperature 0.3–0.5 with
   `format=` (structured decoding likes low temp); the encouraging tone comes
   from the persona text, not sampling heat.

### Graceful degradation — exact `ollama` API calls

```python
import ollama  # pip install ollama  (MIT; deps: httpx, pydantic)

def generate_coach_report(summary_json: str, cfg: CoachConfig) -> str | None:
    """Returns Markdown narrative, or None if the LLM is unavailable.
    The caller always writes the deterministic metrics report regardless."""
    client = ollama.Client(host=cfg.host)  # default http://localhost:11434
    try:
        # optional cheap preflight; raises the same ConnectionError
        client.list()
        resp = client.chat(
            model=cfg.model_tag,                     # "qwen3:8b"
            messages=[
                {"role": "system", "content": PERSONA_PROMPT},  # stable prefix
                {"role": "user", "content": summary_json},      # volatile tail
            ],
            format=CoachReport.model_json_schema(),  # constrained decoding
            options={"temperature": 0.4, "num_ctx": 8192},
            think=False,                             # qwen3: skip chain-of-thought
        )
        report = CoachReport.model_validate_json(resp.message.content)
        return render_markdown(report)
    except ConnectionError:
        # server not running — verified: ollama-python raises builtin
        # ConnectionError ("Failed to connect to Ollama. ...")
        log.warning("Ollama not running; writing metrics-only report")
        return None
    except ollama.ResponseError as e:
        if e.status_code == 404:                     # model not pulled
            log.warning("Model %s not pulled (`ollama pull %s`)", cfg.model_tag, cfg.model_tag)
        else:
            log.warning("Ollama error %s: %s", e.status_code, e.error)
        return None
```

Testing split (per the reference doc): mock `ollama.Client` for all unit tests;
one integration test that calls the real server, skipped with
`pytest.mark.skipif` when `Client().list()` raises `ConnectionError`.

## Search log

Tooling note: `ollama.com` (library pages and blog) returned **403 via both
WebFetch and the session's egress proxy** (`CONNECT` policy denial), so all
Ollama-library-specific numbers (tag sizes, pull counts, model release dates)
are from secondary sources and marked (u). GitHub repo stats and PyPI
versions were fetched from primary APIs and are verified.

Searches run (2026-07-05):
1. `Ollama Python library structured outputs JSON schema 2026` — confirmed
   `format=` JSON-schema support + constrained decoding; sources: ollama.com
   blog (via snippets), docs.ollama.com, instructor docs, several 2026 guides.
2. `best small local LLM 8GB Mac 2026 qwen3 gemma3 llama3.2 phi-4 comparison` —
   model landscape; sitepoint, localaimaster, daily.dev, microcenter roundups.
3. `mlx-lm vs ollama vs llama.cpp Apple Silicon 2026 local inference` —
   performance comparisons; surfaced the Ollama-on-MLX announcement; arxiv
   2511.05502 comparative study.
4. `ollama library qwen3:8b gemma3:4b phi4-mini llama3.2:3b model size GB tags`
   — tag existence + sizes (secondary).
5. `"Ollama" MLX Apple Silicon preview announcement date 2026` — Ollama 0.19 +
   MLX preview dated 2026-03-30 (Medium, AppleInsider, HN corroboration).
6. `vLLM macOS Apple Silicon support CPU only Metal 2026` — CPU backend
   experimental/slow; new `vllm-project/vllm-metal` plugin (Docker-contributed,
   v0.2.0 April 2026).
7. `ollama gemma 4 E4B qwen3 2507 release new small models 2026` — Gemma 4
   E-series 2026-04-02, gemma4 tag on Ollama, qwen3 2507 variants, gpt-oss:20b.
8. `ollama most pulled models 2026 ...` — pull-count ranking (llama3.1 116.5M,
   llama3.2 74.5M, gemma3 38.1M as of June 2026, secondary).

Primary fetches:
- GitHub API (`search/repositories`): ollama/ollama 175,523★ MIT pushed
  2026-07-04; ggml-org/llama.cpp 119,355★ MIT; vllm-project/vllm 85,426★
  Apache-2.0; abetlen/llama-cpp-python 10,458★ MIT; ollama/ollama-python
  10,249★ MIT; ml-explore/mlx-lm 6,194★ MIT; lmstudio-ai/lms 5,038★ MIT.
- PyPI JSON API: ollama 0.6.2 (2026-04-29), llama-cpp-python 0.3.32
  (2026-06-29), mlx-lm 0.31.3 (2026-04-22), vllm 0.24.0 (2026-06-30),
  lmstudio 1.5.0 (2025-08-22).
- raw.githubusercontent.com — ollama-python `README.md`,
  `examples/structured-outputs.py`, `ollama/_client.py` (verified: `format=`
  schema param, `think` param, `ConnectionError` on connect failure,
  `ResponseError.status_code` on HTTP errors).
