# Research: resumable-upload

**Date:** 2026-07-06 / **Triggering use-case:** ../ideas/use-cases/badmintontrack-integration.md

## Need summary

`badminton_backend/` needs a LAN-only ingest endpoint (separate, un-tunneled
port, e.g. 8001) that accepts 1–2 GB 1080p60 video clips from the Flutter app
over flaky home WiFi, where a mid-transfer drop or app kill **must not**
restart the upload from byte zero. The upload must also never touch cellular
— gated by `connectivity_plus` on the Flutter side (owner-mandated, verified
separately below). Two protocol shapes are on the table: adopt the **tus**
resumable-upload protocol (either a reference/third-party server, or reimplement
the wire protocol by hand in FastAPI) vs a fully bespoke chunk+offset protocol
(client sends `upload_id` + byte offset, server tracks progress in SQLite and
reassembles on disk). Python 3.11+ / FastAPI / SQLite on the server; Flutter/
Dart (`http` or `dio`) on the client. Search access was available for this
session — no offline fallback needed.

## Candidates evaluated

Scoring: functionality fit 30%, maintenance 20%, community 20%, documentation
15%, licence 10%, dependency footprint 5%. Versions/dates verified live via
pub.dev and GitHub page fetches on 2026-07-06 (`tus.io` itself 403'd through
the proxy; worked around via the protocol's GitHub-hosted markdown source).
11 candidates evaluated (3 server-side, 8 Flutter/Dart client-side) — above
the 5-candidate quality gate, close to the 15-candidate aim; coverage is
adequate, not thin, for a fairly narrow ecosystem (tus-for-FastAPI and
tus-for-Dart are both small niches).

| Name | Layer | Stars / downloads | Last release | Licence | Weighted | Decision |
|---|---|---|---|---|---|---|
| tusc | client (Dart) | 160 pub pts, 14 likes, 1.6k wk dl | 3.0.0 (2026-03, ~4mo ago) | MIT | **4.48** | **adopt** |
| tusd | server (Go) | 3.8k ★ | v2.10.0 (2026-06-16) | MIT | 4.25 | skip (spec reference only — wrong runtime/footprint) |
| flutter_upchunk | client (Dart) | 140 pub pts, 16 likes, 4.05k wk dl | 2.0.3 (2025-08, ~11mo ago) | MIT | 3.875 | skip (viable fallback, more manual wiring than tusc) |
| another_tus_client | client (Dart) | 130 pub pts, 1 like, 700 dl | 3.2.6 (2025-05, ~14mo ago) | MIT | 3.53 | skip |
| tus_file_uploader | client (Dart) | 130 pub pts, 13 likes, 75 dl | 0.0.34 (2024-08, ~23mo ago) | MIT | 3.2 | skip |
| fastapi-tusd | server (Python) | 13 ★, 0 open issues | 0.100.2 (2024-05-10) | MIT | 3.15 | skip |
| FasTUS | server (Python) | n/a (Gitea, no star metric) | 0.0.002 | Unlicense | 3.15 | skip |
| tus_client (jjmutumi) | client (Dart) | 34 ★, 25 likes | 1.0.2 (2021-08-19) | MIT | 3.15 | skip — abandoned |
| resumable_upload | client (Dart) | 130 pub pts, 2 likes, 1.85k dl | 0.0.2 (~2yr ago) | MIT | 3.075 | skip |
| fp_resumable_uploads | client (Dart) | 160 pub pts, 2 likes, 2 wk dl | 0.0.3+native-patch (~23mo ago) | MIT | 3.05 | skip |
| chunked_uploader | client (Dart) | 150 pub pts, 35 likes, 1.17k dl | 1.1.0 (~2yr ago) | MIT | 2.725 | skip |

Note: `tus-py-client` (203 ★, MIT, actively maintained per its Dec 2024
release) was found but excluded from scoring — it's a *Python* tus client,
irrelevant to a Flutter mobile app. `pro_resumable_upload`, referenced in a
Medium post, appears to just be a rebrand/blog-name for the `resumable_upload`
pub.dev package (same publisher, `theproindia.com`) — treated as one entry,
not double-counted.

## Per-candidate notes (top 8)

### 1. tusc — 4.48 — adopt (client)
Pure-Dart tus client, MIT, verified publisher (`dev.lamt.dev`), v3.0.0
published ~4 months ago. Directly matches the use-case's hardest client-side
requirement: `TusPersistentCache` (Hive-backed, `hive_ce` dependency) keeps
upload URL + byte offset on disk so pause/resume survives **app restarts**,
not just in-session pauses — exactly the "queue survives app restarts and
WiFi drops" requirement in the use-case doc. `TusMemoryCache` is available for
simpler cases but the persistent variant is the one this project needs.
Dependencies (`cross_file`, `crypto`, `hive_ce`, `http`, `path`) are all
small/standard. Modest but healthy pub.dev signal (160 points, 14 likes,
1.6k weekly downloads) — small ecosystem overall, this is the strongest
option in it.

### 2. tusd — 4.25 — skip (spec reference only)
The official Go reference server, 3.8k ★, MIT, actively released
(v2.10.0, 2026-06-16), excellent docs, production users (Vimeo, Google per
project claims). Scores well on every axis except fit: running it means a
second language runtime/container on a single-host Docker Compose box whose
whole design philosophy (per `research/fastapi-auth.md` and the
`background-jobs` sibling domain) is "no new infra for a single-user home
server." Its value here is as the **canonical spec implementation** to check
our own FastAPI implementation's headers/status-codes against, not as a
service to run.

### 3. flutter_upchunk — 3.875 — skip (viable fallback)
Dart port of MUX's battle-tested `upchunk` JS library. Highest weekly
downloads among the Dart candidates (4.05k), MIT, reasonably fresh
(v2.0.3, ~11 months). `pause()`/`resume()`/`restart()`/`stop()` plus a
`chunkStart` constructor param that lets a caller resume "in case the upload
fails in chunk x and the instance is lost." The catch: it does **not** ship
its own persistent store — the app would have to persist `chunkStart` (and
the upload's server-side identifier) itself, e.g. in `shared_preferences`,
duplicating what `tusc`'s `TusPersistentCache` already does. Good fallback if
the team ever needs a non-tus chunked protocol, but no reason to prefer it
over tusc for this use-case.

### 4. another_tus_client — 3.53 — skip
Fork of `tus_client_dart`, web-compatible (adds `TusIndexedDBStore` for web,
irrelevant here since this feature is mobile-only per the use-case's own
scope). MIT, v3.2.6 but last published ~14 months ago — slower cadence than
tusc. Weak community signal (1 like, 700 downloads). Pulls in
`speed_test_dart` as a dependency, which is an odd/unnecessary addition for a
resumable-upload client and a mild footprint smell.

### 5. tus_file_uploader — 3.2 — skip
Explicitly documents storing "information about the uploading process in
persistent storage to allow resume after app's crashing" — functionally
close to tusc — but very low adoption (13 likes, 75 total downloads) and
stale (last published ~23 months ago). Not enough of a track record to trust
for a data-integrity-sensitive path over tusc.

### 6. fastapi-tusd — 3.15 — skip
A real tus-protocol implementation for FastAPI (HEAD/POST/PATCH/DELETE,
file + S3 storage backends, Pydantic-typed). MIT, 13 ★. Last commit
2024-05-10 — over two years stale as of this research date — and the code
still carries visible `TODO`s (e.g. around `prefix` handling). Too thin and
too stale to depend on for the byte-exact offset/concurrency logic that a
resumable upload server lives or dies on; a bug here corrupts video files
silently. S3 backend support is dead weight — this project stores directly
on the home server's disk.

### 7. FasTUS — 3.15 — skip
Another FastAPI tus-protocol template, Unlicense (public domain), hosted on
Gitea rather than GitHub, no star/download metric to gauge adoption. README
frames it as a "template," inviting PRs — reads as a starting point to fork
from, not a maintained dependency to pin. Same conclusion as fastapi-tusd:
promising shape, not enough of a track record.

### 8. tus_client (jjmutumi) — 3.15 — skip, abandoned
The original pure-Dart tus client (34 ★, 25 likes, MIT). Last release
2021-08-19 — five years stale. Superseded in practice by its forks
(`another_tus_client`, and indirectly `tusc`). No reason to pick this over
its actively-maintained descendants.

### Also considered, below top 8
`resumable_upload`/"pro_resumable_upload" (bespoke chunked protocol,
`shared_preferences`-backed resume, stagnant at 0.0.2 for ~2 years),
`fp_resumable_uploads` (fastpix.io-published, dio-based, good README but
essentially zero adoption — 2 weekly downloads), `chunked_uploader`
(dio-based sequential chunking with progress callbacks, but no documented
persistence/resume-after-restart story at all — closest to "just a chunked
`POST` loop," not a resumable protocol).

## connectivity_plus verification

- **Current version:** 7.2.0, published ~11 days before this research date
  (pub.dev fetch, 2026-07-06). Actively maintained — not remotely stale.
- **Maintenance status:** verified publisher `fluttercommunity.dev`. No
  discontinued/deprecated notice on the pub.dev listing. Strong ecosystem
  signal: 160 pub points, 4,070 likes, 2.85M downloads. **Not superseded** —
  it remains the fluttercommunity package for this purpose (the
  `internet_connection_checker_plus` package surfaced in search is a
  *complementary* actual-internet-reachability probe, not a replacement for
  connectivity-type detection).
- **Licence:** BSD-3-Clause.
- **Exact 2026 API** (pub.dev example fetch, current for 7.x):
  ```dart
  final Connectivity _connectivity = Connectivity();

  // Stream of connectivity changes — NOTE: emits a List, not a single value,
  // because a device can have >1 active interface at once (e.g. WiFi + VPN).
  StreamSubscription<List<ConnectivityResult>> _sub =
      _connectivity.onConnectivityChanged.listen((List<ConnectivityResult> results) {
    final onWifi = results.contains(ConnectivityResult.wifi);
    // gate: resume() only if onWifi; pause() immediately otherwise
  });

  // One-shot check (e.g. before enqueueing a new upload):
  final List<ConnectivityResult> current = await _connectivity.checkConnectivity();
  ```
  `ConnectivityResult` enum values (verified via pub.dev API docs):
  `wifi`, `mobile`, `ethernet`, `bluetooth`, `vpn`, `satellite`, `other`,
  `none`.
- **Load-bearing gotcha for this use-case:** both `onConnectivityChanged` and
  `checkConnectivity()` return `List<ConnectivityResult>`, **not** a single
  `ConnectivityResult` (that was the pre-6.x API). The WiFi-only gate must
  check `results.contains(ConnectivityResult.wifi)` and must treat "wifi
  absent from the list" as pause-worthy even if `mobile` or `vpn` is present
  — i.e. never treat "some connectivity" as good enough; only WiFi is. The
  package's own docs additionally warn that connectivity *type* isn't proof
  of a working route to the LAN server — pair this with the upload client's
  own request-level timeout/retry (already needed for resumability), not as
  a substitute for it.

## Recommendation

**Protocol: adopt the tus Core + Creation wire protocol; hand-roll the
FastAPI server against it; adopt `tusc` as the Flutter client.**

Rationale: the two existing Python/FastAPI tus servers (fastapi-tusd,
FasTUS) are both too thin and too stale (2+ years since last commit, single-
digit-to-no community signal, visible TODOs) to trust for logic where a bug
silently corrupts a family's video footage — byte-offset bookkeeping and
concurrent-PATCH handling need to be code this project fully owns and tests,
matching the "hand-roll a small, fully-tested surface instead of depending on
a thin wrapper" call already made for auth (`research/fastapi-auth.md`).
Running the actual `tusd` Go binary would work but adds a second language
runtime to a single-host Docker Compose box that deliberately has no
extra infra (same philosophy as the sibling `background-jobs` domain). The
compromise that gets the best of both: implement only the protocol's Core
+ Creation extension by hand in FastAPI (skip Checksum/Concatenation/
Expiration — a single trusted LAN client doesn't need them), which is a
small, fully-testable router — and in exchange get to use `tusc` client-side
for free, which already solves the hardest client requirement (persistent
resume across app kills) rather than hand-rolling that in Dart too.

### Server: FastAPI router on the LAN-only port (8001, not proxied by nginx)

Endpoints (mounted at `/uploads`, behind the existing JWT `require_player`
dependency so every upload is scoped to the uploading account/player):

- `OPTIONS /uploads` — protocol discovery. Response headers:
  `Tus-Resumable: 1.0.0`, `Tus-Version: 1.0.0`, `Tus-Extension: creation`,
  `Tus-Max-Size: <bytes>` (set a generous cap, e.g. 4 GiB, comfortably above
  the ~2 GB/10-min clip guidance). `tusc` calls this first to confirm server
  capabilities.
- `POST /uploads` — create an upload. Request headers: `Tus-Resumable:
  1.0.0`, `Upload-Length: <total-bytes>`, optional `Upload-Metadata:
  <base64 key,value pairs>` (tusc sends `filename`, and the app should also
  send `sessionId`/`playerId` here so the server can persist ownership without
  a second round trip). Server: generate `upload_id` (uuid4), pre-create a
  zero-length file at `storage_path`, insert an `uploads` row (`offset_bytes
  = 0`, `status = 'in_progress'`). Response: `201 Created`,
  `Location: /uploads/{upload_id}`, `Tus-Resumable: 1.0.0`.
- `HEAD /uploads/{upload_id}` — resume probe. Response: `Upload-Offset:
  <offset_bytes>`, `Upload-Length: <total_bytes>`, `Cache-Control: no-store`,
  `Tus-Resumable: 1.0.0`. `404` if unknown id, `410 Gone` if
  `status in ('complete', 'aborted', 'expired')`.
- `PATCH /uploads/{upload_id}` — append a chunk. Request headers:
  `Content-Type: application/offset+octet-stream`, `Upload-Offset:
  <claimed-offset>`, `Tus-Resumable: 1.0.0`; body = raw chunk bytes
  (`Request.stream()`, never buffer the whole chunk in memory — this is a
  1–2 GB file). Server validates `Upload-Offset == uploads.offset_bytes`
  for that row (`409 Conflict` otherwise — this is what makes resume safe:
  the client always re-probes via HEAD before PATCHing after a drop). Opens
  the file `r+b`, seeks to offset, writes+flushes the chunk, updates
  `offset_bytes` in SQLite in the same transaction. If `offset_bytes ==
  total_bytes` afterwards, set `status = 'complete'` (this is the hook stage
  3's job-queue enqueue attaches to). Response: `204 No Content`,
  `Upload-Offset: <new-offset>`, `Tus-Resumable: 1.0.0`.
- `DELETE /uploads/{upload_id}` — optional, lets the app abandon a partial
  upload (e.g. re-recorded clip); mark `status = 'aborted'`, unlink the file.

Concurrency/crash-safety: guard each upload_id's PATCH handler with an
in-process `asyncio.Lock` (single-worker Docker Compose host, no need for a
distributed lock) so two overlapping PATCHes for the same id can't race the
offset. On process restart mid-upload, the file's actual byte length and the
SQLite `offset_bytes` are the resumption source of truth — the next `HEAD`
after restart reports them correctly with no special recovery code needed,
as long as each PATCH's write is flushed before the SQLite commit.

**SQLite table:**
```sql
CREATE TABLE uploads (
    id            TEXT PRIMARY KEY,        -- upload_id (uuid4 str)
    account_id    TEXT NOT NULL,           -- JWT sub, ownership scoping
    player_id     TEXT NOT NULL,
    session_id    TEXT,                    -- training session FK; may arrive via Upload-Metadata
    filename      TEXT NOT NULL,
    total_bytes   INTEGER NOT NULL,
    offset_bytes  INTEGER NOT NULL DEFAULT 0,
    storage_path  TEXT NOT NULL,           -- under the existing gitignored uploads dir
    status        TEXT NOT NULL DEFAULT 'in_progress',  -- in_progress | complete | aborted | expired
    created_at    TEXT NOT NULL,
    updated_at    TEXT NOT NULL
);
```
(`status = 'complete'` rows are exactly the input queue for the
`background-jobs` domain's job enqueue — that domain's research should treat
this table as its trigger source, not invent a separate "pending analysis"
table.)

### Client: Flutter, `tusc` package

- `TusClient` per upload, backed by `TusPersistentCache` (Hive) so the
  upload's server URL + last-known offset survive app restarts — satisfies
  "queue survives app restarts and WiFi drops mid-transfer" directly.
  Chunk size: 5–10 MB (balances resumption granularity against per-chunk HTTP
  overhead on a home WiFi link; tus's client-driven chunking means this is a
  pure client-side tuning knob, no server change needed).
- Wrap `client.upload()`/`pause()`/`resume()` behind the
  `connectivity_plus`-driven queue (stage 2 of the use-case): on
  `onConnectivityChanged`, `pause()` the in-flight upload the instant
  `ConnectivityResult.wifi` drops out of the emitted list, and `resume()`
  (which internally re-does the tus HEAD probe) when it reappears — never on
  `mobile` alone, matching the non-negotiable WiFi-only constraint.
- Point `tusc` at `http://<lan-ip>:8001/uploads` (the manually-entered LAN
  server address from stage 5) — plain HTTP is fine since this port is, by
  the use-case's own constraint, unreachable from outside the LAN/tunnel.

This pairing (hand-rolled tus-subset server + `tusc` client) gives a
/plan-ready shape: Stage 1 tasks are "implement the `uploads` router +
table + pytest coverage of offset/conflict/resume paths" and "wire `tusc`
into the app's upload queue," which is exactly the granularity `/plan` needs.

## Search log

WebSearch (2026-07-06): `tus protocol resumable upload server 2026`; `tusd
resumable upload server GitHub tus.io`; `FastAPI resumable upload tus python
library`; `flutter tus client package pub.dev resumable upload`;
`connectivity_plus pub.dev flutter package latest version 2026`; `dio flutter
chunked resumable file upload package`; `FasTUS FastAPI tus resumable upload
GitHub stars maintained`; `"pro_resumable_upload" flutter pub.dev`; `FastAPI
large file upload SQLite track offset resume custom protocol example`;
`flutter dio upload large video byte offset resume network drop tutorial
2026`; `tus protocol PATCH Upload-Offset Upload-Length header spec`.

WebFetch (2026-07-06): pub.dev pages for `connectivity_plus` (+ `/example`),
`tusc`, `another_tus_client`, `tus_client`, `tus_file_uploader`,
`resumable_upload`, `fp_resumable_uploads`, `chunked_uploader`,
`flutter_upchunk`, and the `ConnectivityResult` API doc page; GitHub pages
for `tus/tusd`, `tus/tus-py-client`, `liviaerxin/fastapi-tusd`,
`jjmutumi/tus_client`; PyPI page for `fastapi-tusd`; the tus protocol spec
via `raw.githubusercontent.com/tus/tus-resumable-upload-protocol/main/protocol.md`
(direct `tus.io` fetch returned 403 through the proxy — worked around via the
GitHub-hosted markdown source, same pattern noted in `research/fastapi-auth.md`
for `fastapi.tiangolo.com`).

Blocked/unavailable: `tus.io` (403 via proxy). `FasTUS` star/fork counts
unavailable (Gitea doesn't expose them the way GitHub does) — noted as such
in its candidate row rather than guessed.
