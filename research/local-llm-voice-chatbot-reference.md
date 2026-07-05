# Reference: local-LLM voice chatbot porting notes (helperBot)

**Added:** 2026-07-05
**Source:** investigation of a sibling project ("helperBot"), run in that
project's own Claude Code session, findings pasted back here.
**Not** a `/research` domain-scoring doc (no candidate comparison/scoring —
that skill is for evaluating OSS libraries, not reading a codebase we already
have access to). Kept as raw reference notes for reuse in `badminton_track/`.

---

## Relevance to BadmintonTrack-12

Cross-checked against `ideas/use-cases/badmintontrack-12.md`:

- **STT is the most directly reusable piece.** `utils/stt.py` there
  (ffmpeg → 16kHz mono WAV → `faster-whisper`, CPU `int8`, whole-file
  transcription, no VAD) is a small, dependency-light pattern that maps
  cleanly onto a **new potential idea**: audio logging — the parent/coach
  records spoken notes during or after a session, transcribed locally and
  attached to the session log, instead of (or alongside) typed notes. Not yet
  in `ideas/pool.md`; flag for `/intake` if the owner wants to pursue it.
- **LLM transport differs from our plan.** helperBot proxies through
  llama.cpp's `llama-server` via the `openai` SDK pointed at a local
  `base_url`. BadmintonTrack-12 Module 4 already commits to Ollama's own
  Python package instead (`ideas/use-cases/badmintontrack-12.md:119-123`) —
  simpler, no separate server process to manage. The transport-level details
  below (§1) don't port directly, but the **prompt-structuring lesson does**:
- **Stable/volatile system-prompt split is worth stealing regardless of
  backend.** helperBot's biggest measured latency win (§7 below) came from
  never perturbing the token-for-token-stable part of the prompt (persona +
  memory) and isolating per-turn-changing content (time, current activity) in
  a separate tail appended last. For Module 4, the equivalent would be:
  keep the persona/tone instructions + drill library as a fixed block, and
  put the per-run metrics JSON (which changes every call) last. Ollama's
  server also does prefix-cache reuse across calls with an identical prefix,
  so the same principle should still pay off — worth a perf check once
  Module 4 exists, not worth pre-optimizing before it does.
- **TTS (GPT-SoVITS) and the Telegram bot plumbing are not relevant** —
  badminton_track has no voice-output requirement and is a CLI tool, not a
  chat bot. Skip that section (§2 TTS, most of §3) entirely when porting.
- **Testing pattern worth copying:** helperBot's `tests/harness.py` distinction
  between fast mocked tests and one integration test that actually boots the
  real local server. Module 4's Ollama call should get the same split — mock
  it for the bulk of `/tdd` work, one real-Ollama integration test gated
  behind "Ollama running" (mirrors the existing constraint in
  `badmintontrack-12.md:123`: "fail gracefully with the metrics report intact
  if Ollama isn't running").

---

## Full findings (verbatim from the investigating session)

### 1. LLM Runtime

**Runtime:** llama.cpp's `llama-server` (OpenAI-compatible HTTP server), launched as an external Windows process — not Dockerized, not systemd, not Python-spawned.

**Startup (`start.ps1`, full script read):**
- Reads `exe`/`model`/`port`/`args` out of `config.yaml` via inline `python -c "import yaml; ..."` calls (`start.ps1:8-19`).
- Kills any stale instance, then `Start-Process -FilePath $llamaExe -ArgumentList @("-m", $llamaModel) + ($llamaArgs -split ' ') -WindowStyle Hidden` (`start.ps1:24`).
- Polls `http://127.0.0.1:$llamaPort/health` for up to 60s (`start.ps1:27-35`).
- Then starts the FastAPI admin panel (`uvicorn web.app:app`) as a background job using a **hardcoded venv path** `Minegenie-env\Scripts\python.exe` (`start.ps1:38-44`), opens it in a browser, then runs `python bot.py` in the foreground.
- `finally` block force-kills `llama-server` and the web job on exit (`start.ps1:62-65`).
- The Python app itself never spawns llama-server — `utils/vram.py`'s `VRAMManager` also shells out to PowerShell (`Get-Process llama-server | Stop-Process -Force`, `utils/vram.py:16-19`) to stop/restart it around VRAM-exclusive work (currently only confirmed for ComfyUI image generation, see §7).

**Model:** No filename is committed — `config.yaml.example` uses placeholders (`your-model-filename.gguf`, lines 4/66). The model actually used during development, per `docs/perf_baseline.md:6,39,59`:
> `qwen2.5-7b-instruct Q4_K_M, -c 4096, -ngl 12, flash-attn, KV q8_0, batch 2048/1024, 16 threads`

i.e. **Qwen2.5-7B-Instruct, Q4_K_M quant**, run on a 4GB laptop GPU (RTX A500) with only 12 layers offloaded (`-ngl 12`), rest on CPU. No comment in-repo explains the model choice.

**llama-server launch flags** (`config.yaml.example:64-84`, `llama.args`):
```
-c 4096  --flash-attn on  -ctk q8_0  -ctv q8_0  -ngl 12
--batch-size 2048  --ubatch-size 1024  --threads 16
--api-key <key>  -rea off  --jinja  --cache-ram 2048
--parallel 1  --kv-unified  --no-mmap  --port 8080
```

**App ↔ LLM transport (`core/llm.py`):** Official `openai` Python SDK (`requirements.txt:2` — `openai>=1.0`), used purely as an OpenAI-compatible HTTP client, never `api.openai.com`.
```python
# core/llm.py:72-75
self._client = AsyncOpenAI(base_url=cfg["base_url"], api_key=cfg["api_key"])
```
```python
# core/llm.py:199-204
resp = await self._client.chat.completions.create(
    model=self._model, messages=cont_msgs,
    max_tokens=self._max_tokens, temperature=self._temperature,
)
```
`base_url` = `http://127.0.0.1:8080/v1` (`config.yaml.example:2`). Endpoint hit: `/v1/chat/completions`. **Blocking, non-streaming** — `stream=` is never passed. No timeout/retry on the call itself; errors bubble to `core/router.py:47-49` where a bare `except Exception` falls back to a literal `"..."` reply.

Note: `stream_client.py` / `streaming/*` in this repo are **not** LLM token-streaming — they're a Bilibili live-chat (danmaku) integration, unrelated to voice chat. Ignore them when porting.

**Generation params sent to the server:** only `max_tokens` (default 600 in code, `config.yaml.example:5` sets 200) and `temperature` (default 0.8 in code, config sets 0.9). No `top_p`/`top_k`/`repeat_penalty`/`stop` set from Python — those fall back to server/model-template defaults. A **continuation loop** re-prompts up to 4x with a `"Continue."` user turn if `finish_reason == "length"` (`core/llm.py:198-214`) to stitch together truncated replies.

**System prompt handling** — split into two parts specifically to preserve llama-server's KV-cache prefix reuse:
- *Stable system* (`_build_stable_system`, `core/llm.py:97-124`): character card (`characters/<name>/system.md`) + date + fixed response-style rules + memory block (`core/db.py:297-314`) + familiarity label. Cached per `chat_id` in-process (`core/llm.py:83-85`), invalidated after 300s idle (`stable_cache_idle_s`, `config.yaml.example:9`) or on character switch/reset.
- *Volatile tail* (`_build_volatile_tail`, `core/llm.py:126-156`): current activity + `HH:MM` time + language hint + anti-repetition note — placed right before the user turn so per-turn-changing tokens never dirty the long stable prefix.
- Message order: `[stable system] + history (token-budget-truncated) + [volatile system] + [user]` (`_build_messages`, `core/llm.py:158-190`).

This "stable-prefix" optimization was a deliberate perf project (see §7) — worth replicating if porting to another llama.cpp-backed setup, since KV-prefix cache misses were the dominant latency cost.

### 2. Voice I/O Pipeline

**STT — `utils/stt.py` (51 lines):**
- `faster-whisper`, CPU-only, `compute_type="int8"`, default model size `"base"` (`utils/stt.py:2-3,16`). Loaded once as a module-level singleton, lazy-imported.
- Input is a Telegram voice note (Opus-in-OGG). Converted via a raw `ffmpeg` subprocess to 16kHz mono WAV: `["ffmpeg", "-y", "-i", ogg_path, "-ar", "16000", "-ac", "1", wav_path]` (`utils/stt.py:35-38`), written to a temp file, deleted after use.
- `model.transcribe(wav_path, beam_size=5)` (`utils/stt.py:44`), no forced language (auto-detect via `info.language`).
- **No VAD, no chunking** — the whole file is transcribed in one call.
- Called from `handlers/messages.py:104-155` (`on_voice_message`): downloads voice → temp `.ogg` → `run_in_executor(stt_mod.transcribe, ...)` (off event loop) → feeds transcript into the same router as text messages.

**TTS — `tts/__init__.py` (252 lines) + `tts/handler_infer.py` (279 lines):**
- **GPT-SoVITS v2 Pro**, confirmed as the active/chosen backend after benchmarking (`docs/tts_backends_tried.md:8`) against two rejected alternatives: a CPU ONNX export (2-5x slower than real-time) and MOSS-TTS (~58x real-time factor, unusable).
- Invocation is **not HTTP** — it's a persistent subprocess with a JSON-line protocol over stdin/stdout: `subprocess.Popen([python, "-u", script], stdin=PIPE, stdout=PIPE, ...)` (`tts/__init__.py:106-115`), so the model stays resident in VRAM (no per-call cold start). Startup handshake waits up to 180s for `{"status":"ready"}` (`tts/__init__.py:141-163`).
- Reference-voice ("voice cloning") wavs are pre-built offline by `scripts/build_ref_wavs.py`: merges short clips into >=8s references per language/mood, writes `ref_wavs.yaml` with transcripts.
- At inference, `handler_infer.py` picks a ref wav by language prefix + mood, then calls `get_tts_wav(ref_wav_path=..., prompt_text=..., text=..., ref_free=..., use_cuda_graph=False)` (`tts/handler_infer.py:207-225`) from GPT-SoVITS's own `inference_webui` module, writes int16 PCM WAV via `scipy.io.wavfile.write` (`tts/handler_infer.py:258`).
- Output sent back as a Telegram voice note: `await ctx.bot.send_voice(chat_id, voice=f)` (`handlers/messages.py:42`).
- Per-character voice config example — `characters/natsume/voice.yaml`: model paths + per-mood inference overrides (e.g. `top_k`, `temperature`, `sample_steps`, `speed`).
- **Discrepancy found:** `tts/__init__.py:4` and `CLAUDE.md:47-48` claim TTS runs inside `VRAMManager.run_exclusive()` (to stop llama-server first), but no such call site was found wrapping `tts_client.synthesize()` — the only confirmed `run_exclusive` caller is ComfyUI image generation (`handlers/commands.py:265-267`). Flag this if porting; verify empirically rather than trusting the docstring.

**Wake-word / push-to-talk:** **None exists.** Repo-wide search for `wake_word`/`push_to_talk`/`hotword` returns zero matches. Voice input is entirely Telegram-native — the user explicitly records and sends a voice message; there's no continuous listening or hotword gating.

**End-to-end flow (text or voice path, both converge on the same router):**
```
[voice note received] -> ffmpeg OGG->16kHz WAV -> faster-whisper transcribe (blocking, whole-file)
                                                        |
[text message received] --------------------------> core.router.handle_message()
                                                        |
                                    LLMClient.chat() -> blocking POST /v1/chat/completions
                                                        |
                                    emotion.detect() on reply text -> TTS mood
                                                        |
                                    (if voice_on) TTS subprocess JSON request -> full WAV file
                                                        |
                                    reply text sent to Telegram + WAV sent as voice note
```
Nothing streams end-to-end: STT is whole-utterance, LLM call is blocking/non-streaming, and TTS returns a complete WAV only after full synthesis (also explicitly noted as a limitation in `docs/voxtral-research.md:75-80`, which researches a streaming alternative). The only "streaming" concept in the repo is unrelated Bilibili chat ingestion.

Avatar/Live2D (`avatar/client.py`, `avatar/server.py`) is a **separate visual layer** driven off emotion/action tags in the reply text via a WebSocket — not part of the audio path, safe to skip if you only want voice chat.

### 3. Architecture & Code Layout

```
state.py            - singleton bootstrap (must import before handlers)
bot.py               - python-telegram-bot entry point, handler registration, scheduler
core/
  llm.py             - LLMClient: prompt assembly, stable/volatile split, OpenAI-SDK call
  router.py          - handle_message(): STT/text -> LLM -> emotion -> TTS orchestration
  memory.py          - thin wrapper over db.py memory tables
  db.py              - SQLite persistence (history, memory, familiarity, scheduled msgs)
  emotion.py         - keyword-based emotion classifier + TTS mood mapping
  extractor.py       - background fact/opinion extraction after each turn
handlers/
  messages.py        - on_message (text path), on_voice_message (STT path)
  commands.py        - slash commands (/reset, /character, /tts, /image, /dream, ...)
companion/
  character.py       - character loader (system.md, voice.yaml, schedule.yaml)
  dream.py           - nightly reflection job (proactive messages, memory consolidation)
  scheduler.py       - polls & sends due proactive messages
utils/
  stt.py             - faster-whisper wrapper
  vram.py            - VRAMManager.run_exclusive() - stop/restart llama-server
tts/
  __init__.py        - TTSClient (subprocess + JSON-line protocol)
  handler_infer.py   - the actual GPT-SoVITS inference script run in a subprocess
avatar/              - Live2D visual layer (separate from voice)
characters/<name>/   - system.md, voice.yaml, ref_wavs.yaml, emotion.yaml, schedule.yaml
```

**Singleton init order (`state.py`, must be imported first per `CLAUDE.md:46`):** config load -> DB init -> per-chat character state -> default character load -> `llm = LLMClient(...)` / `vram = VRAMManager(...)` -> optional `tts_client` -> optional computer-use tools -> optional ComfyUI client -> per-chat dict rehydration. Because Python only executes a module body once, the first `import state` anywhere triggers this whole chain before any handler runs — this is the piece most worth replicating exactly if you don't want import-order bugs.

**Entry point (`bot.py`):** `python-telegram-bot>=21.0`, `ApplicationBuilder().token(...).post_init(post_init).build()`, then `app.run_polling(...)` (long-polling, no webhook). 13 `CommandHandler`s + one `MessageHandler(filters.TEXT)` + one `MessageHandler(filters.VOICE)`.

**Conversation state (`core/db.py`, SQLite at `data/helperBot.db`):**
- `chat_history(id, chat_id, role, content, meta, created_at)` — rolling log, windowed to `context_messages` (default 20) messages per call via `load_history()`.
- `memory(chat_id, character, subject, fact, mem_type, importance, created_at)` — facts/opinions injected into the stable system prompt.
- `familiarity(chat_id, character, score, ...)` — relationship-score label injected into the prompt.
- `scheduled_messages` — pre-generated proactive messages (dream job).

History flow: on each `LLMClient._build_messages()` call, the user message is appended to `chat_history` first, then the window is reloaded to build the prompt; the assistant reply is appended after generation.

### 4. Dependencies & Environment

**`requirements.txt` (full):**
```
python-telegram-bot>=21.0
openai>=1.0
pyyaml>=6.0
faster-whisper>=1.0
numpy>=1.24
fastapi>=0.100
uvicorn>=0.24
httpx>=0.25
jinja2>=3.1
apscheduler>=3.10
tzlocal>=3.0
ddgs>=9.0
pytest>=7.0
pytest-asyncio>=0.21
blivedm>=2.0
```
Notably: **no `torch`, no `onnxruntime-gpu`, no `pydub`/`soundfile`** — GPU-heavy work (llama-server, GPT-SoVITS) runs as external OS processes with their own environments, not as in-process Python deps of this repo.

**System-level deps:**
- `ffmpeg` — required as a system binary, invoked via subprocess for OGG->WAV conversion (`utils/stt.py:35-38`). Not in `requirements.txt`.
- `llama-server` binary (llama.cpp build) — external, path configured in `config.yaml`.
- GPT-SoVITS — a **separate Python environment/venv** with its own torch/CUDA stack, invoked via a configured interpreter path (`tts.backends.sovits.python`/`script` in `config.yaml.example:39-40`), not part of this repo's venv.
- No CUDA/cuDNN/Metal/ONNX runtime references in the core bot code itself — GPU requirements live entirely inside the external llama-server and GPT-SoVITS processes.

**Hardware assumptions (from `docs/perf_baseline.md:6`):** developed/tuned on Intel Core Ultra 7 165H + RTX A500 **4GB VRAM** laptop GPU, `-ngl 12` (partial offload — most of a 7B Q4 model doesn't fit in 4GB). CPU-only is plausible for the LLM (llama.cpp supports it, just slower) and is exactly how STT already runs (`faster-whisper` int8/CPU). TTS (GPT-SoVITS) is GPU-bound in practice per `docs/tts_backends_tried.md` benchmarking — a CPU-only ONNX path was tried and rejected as 2-5x too slow.

### 5. Config & Secrets

**Config file:** `config.yaml` (git-ignored, `.gitignore:2`) — never committed; `config.yaml.example` is the tracked template.

Relevant keys (`config.yaml.example`, full read):
```yaml
llm:
  base_url: "http://127.0.0.1:8080/v1"
  api_key: "YOUR_LLAMA_API_KEY"        # consumed by llama-server's own --api-key, not a cloud key
  model: "your-model-filename.gguf"
  max_tokens: 200
  temperature: 0.9
  context_messages: 20
  context_limit: 4096
  stable_cache_idle_s: 300

llama:                                  # controls the llama-server subprocess itself
  exe: <path to llama-server.exe>
  model: <path to .gguf>
  port: 8080
  args: [[-c, 4096], [--flash-attn, on], ...]

stt:
  enabled: true
  model: base                          # tiny/base/small/medium

tts:
  enabled: true
  backend: sovits
  output_dir: ...
  ref_wavs_dir: ...
  default_lang: ...
  default_mood: ...
  backends:
    sovits: { python: <path>, script: <path> }

web:
  port: 8081
  token: "change-me"
```
No sample-rate or device-index keys exist — STT/TTS operate on files (Telegram uploads / generated WAVs), not a live mic/speaker device.

**Local-only enforcement:** by convention, not by a technical block. The `openai` SDK is used purely as an OpenAI-compatible client (`AsyncOpenAI(base_url=..., api_key=...)`) always pointed at `127.0.0.1` (llama-server) or other local services (ComfyUI on `127.0.0.1:8188`). No `anthropic`/`google.generativeai` imports anywhere; no hardcoded cloud endpoints (`api.openai.com`, etc.) in any code path — the one Mistral/Voxtral mention is in a research doc (`docs/voxtral-research.md`), not integrated code. The only other API key in the repo is `TAVILY_API_KEY`, an optional env var for a lore/search script unrelated to the chat path. Bilibili session cookies (`SESSDATA`/`bili_jct`) are also config-only and explicitly documented as sensitive/git-ignored (`docs/streaming-setup.md:57-58`).

### 6. Dev Workflow / Skills

Skills live at `.claude/skills/<name>/SKILL.md`; versioned source of truth is external (`c:\Mine\dev-workflow` per `CLAUDE.md:18`).

| Skill | Purpose |
|---|---|
| `intake` | Turns a free-form idea into a use-case doc, then chains research->plan->implementation, fully automated. |
| `research` | Searches GitHub/web for prior art on a domain, scores it, writes a structured findings doc. |
| `plan` | Converts research + a use-case into an ordered backlog of `TASK-NNN` files, hands off to `/tdd`. |
| `tdd` | Implements one backlog task with strict RED->GREEN->REFACTOR per vertical slice. |
| `audit` | Verifies README/docstrings still match actual code (drift, dead paths, stale docs). |
| `next` | Reads `ROADMAP.md`, applies dependency/scoring logic, recommends the next work item. |

Chain: `ideas/pool.md` -> `/intake` -> `ideas/use-cases/<slug>.md` -> `/research <domain>` -> `research/<domain>.md` -> `/plan <slug>` -> `backlog/tasks/TASK-NNN-*.md` -> `/tdd TASK-NNN` -> archived to `backlog/done/`, logged in `UPDATES.md`. Task files use fixed header lines (`**Status:**`, `**Depends on:**`) that `/tdd` parses for resume/auto-chain — 3 open tasks in `backlog/tasks/`, 34 archived in `backlog/done/`. This maps closely onto a generic `/intake -> /research -> /plan -> /tdd` workflow; the main project-specific bit is the strict status-line parsing convention and the `ideas/pool.md` status board being the single source of truth (mirrored into `ROADMAP.md`).

### 7. Known Issues & Tuning

**Latency was the dominant engineering focus**, tracked in `docs/perf_baseline.md` across three rounds on the dev hardware (4GB GPU):
- Baseline: median total turn **9622ms** (prefill 2004ms, decode 4098ms — decode dominates and varies with response length).
- After splitting stable/volatile system prompt (TASK-022/023): prefill -> 1674ms (16% better; 50% target missed). Root cause found: a **background memory-fact extractor** (`core/extractor.py`) was invalidating the KV-cache stable prefix mid-session by writing to memory between turns.
- After isolating the extractor from the cached stable-prompt string (TASK-028): prefill -> 1490ms overall (25.6% cumulative improvement), turns 5-10 (post-extraction) at ~1109-2092ms, just missing a 1400ms sub-target. Remaining cost: cold KV cache on turn 1, and the volatile history tail growing every turn.

**Key takeaway for a port:** if your target project also proxies through llama-server, replicate the stable/volatile prompt split and the per-chat in-process string cache (`core/llm.py:83-85,97,168-171`) — this is the single biggest lever pulled here, and it's specifically about not perturbing the token-for-token prefix that llama-server's own KV cache keys on.

**Other gotchas surfaced:**
- `VRAMManager.run_exclusive()` (`utils/vram.py`) stops llama-server, runs a GPU-heavy task (confirmed for ComfyUI only), and restarts it in a `finally` block — necessary because the 4GB GPU can't hold the LLM and other GPU work simultaneously. As noted in §2, the docs claim TTS uses this too but no such call site was found — treat as unverified if porting.
- `docs/streaming-setup.md` notes "TTS audio cuts out mid-stream" during the Bilibili integration, traced to VRAM contention, fixed by disabling stream TTS or raising the response interval — same underlying VRAM constraint.
- Error handling on LLM failures is minimal: any exception in `router.py` falls back to a literal `"..."` reply with no retry — acceptable for a hobby bot, worth hardening in a port.
- No VAD/chunking on STT — whole-utterance only, so very long voice notes transcribe as one blocking call.

**Testing:**
- Most unit tests (`tests/conftest.py`) mock `state`/`avatar`/LLM entirely — fast, no real server needed.
- `tests/harness.py` is the exception: it runs full conversation turns against a real temp SQLite DB and will **actually start llama-server** via `utils.vram._start_llama` if it's not already running, probing `/health` first.
- `eval/run_eval.py` is a separate, standalone eval harness — runs a YAML prompt suite against whatever model is currently loaded on llama-server, independent of the Telegram bot/DB, writing dated JSON result files for model-to-model comparison (`eval/report.py` builds the comparison table).
- `tests/test_tts_benchmark.py` is a benchmark script (not a strict unit test) that exercises all TTS backends across characters/languages.

### 8. Minimal Repro (standalone, fresh machine)

Assuming Windows (the repo's scripts are PowerShell) with an NVIDIA GPU (CPU-only LLM works but is slower; TTS is effectively GPU-bound per the benchmarking in `docs/tts_backends_tried.md`):

1. **Install system deps:** `ffmpeg` (add to PATH), a llama.cpp build providing `llama-server.exe`, and a GPT-SoVITS v2 Pro checkout with its own Python venv/torch/CUDA stack.
2. **Get a model:** download a GGUF quant compatible with your VRAM (repo used Qwen2.5-7B-Instruct Q4_K_M for a 4GB card with `-ngl 12`).
3. **Python env:** create a venv, `pip install -r requirements.txt` (core: `python-telegram-bot`, `openai`, `pyyaml`, `faster-whisper`, `fastapi`, `uvicorn`, `apscheduler`).
4. **Config:** copy `config.yaml.example` -> `config.yaml`, fill in: Telegram bot token, `llama.exe`/`llama.model` paths, `tts.backends.sovits.python`/`script` paths pointing at the GPT-SoVITS venv/script, and a `web.token`.
5. **Reference voice:** prepare short reference clips per language/mood, run `scripts/build_ref_wavs.py` to merge them into >=8s ref wavs and generate `ref_wavs.yaml`.
6. **Character card:** write a minimal `characters/<name>/system.md` (persona prompt) — this is the smallest unit needed to get a reply at all; `voice.yaml`/`schedule.yaml`/`emotion.yaml` are optional refinements.
7. **Start everything:** run the equivalent of `start.ps1` — start `llama-server -m <model> <args>`, wait for `/health` 200, then `python bot.py`. (The web admin panel and avatar server are optional for a bare voice-chat MVP.)
8. **Test:** send the bot a text message (exercises LLM path only) and a voice note (exercises STT->LLM->TTS->voice-note-reply path end to end).

The critical minimum to replicate "voice chat with a local LLM" — stripped of memory/scheduler/avatar/streaming/companion features — is: `core/llm.py`'s `LLMClient` (OpenAI-SDK-against-llama-server), `utils/stt.py`'s ffmpeg+faster-whisper wrapper, `tts/__init__.py`'s subprocess-JSON `TTSClient`, and a thin router gluing them together (`core/router.py`'s `handle_message`).
