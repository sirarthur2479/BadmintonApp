# TASK-033 - Flutter WiFi-only gating: connectivity_plus drives the upload queue

**Use case:** [ideas/use-cases/badmintontrack-integration.md](../../ideas/use-cases/badmintontrack-integration.md)
**Research:** [research/resumable-upload.md](../../research/resumable-upload.md)
**Depends on:** TASK-032
**Effort:** S
**Risk:** medium

**Status:** todo

## Goal

Stage 2, the owner's non-negotiable constraint: uploads start and continue
**only** on WiFi — never cellular, never "some connectivity". A
`ConnectivityGate` listens to `connectivity_plus` 7.x (verified current by
research) and drives TASK-032's `pauseAll()`/`resumeAll()` seam: the
in-flight upload pauses the instant WiFi drops out of the emitted list and
resumes automatically when it returns. Load-bearing API gotcha from
research: the 7.x stream emits `List<ConnectivityResult>` (a device can
have several interfaces at once), so the gate must check
`results.contains(ConnectivityResult.wifi)` and must treat a list
containing only `mobile`/`vpn`/`ethernet` as **not** WiFi.

## Acceptance criteria

- `pubspec.yaml`: `connectivity_plus: ^7.2.0`.
- `lib/services/connectivity_gate.dart`: wraps an injectable
  `Stream<List<ConnectivityResult>>` + one-shot `checkConnectivity()`;
  exposes `bool get onWifi` and a `Stream<bool>` of wifi-ness transitions
  (deduplicated — no repeat events while state is unchanged).
- `UploadQueueProvider` integration:
  - `enqueue` no longer auto-starts unconditionally: the upload starts only
    if `onWifi` is currently true, else the row waits `pending`.
  - wifi lost → `pauseAll()` immediately; wifi regained → `resumeAll()`
    (which re-probes offsets per TASK-032) and starts waiting `pending`
    rows.
  - `resumePending()` at startup consults the one-shot check first.
- A list containing `ConnectivityResult.mobile` (or `vpn`, or both) without
  `wifi` never starts or continues an upload — explicit test.
- UI: waiting-for-WiFi state is visible on the queue row ("Waiting for
  WiFi").
- `flutter test` green with a fake connectivity stream; no real plugin
  calls in tests.

## Test plan

RED first in `test/connectivity_gate_test.dart` and additions to
`test/upload_queue_provider_test.dart`:

- `gate reports wifi when list contains wifi among others`
- `gate reports no wifi for mobile plus vpn list`
- `gate stream dedupes unchanged state`
- `enqueue off wifi leaves row pending and starts nothing`
- `wifi loss pauses inflight upload immediately`
- `wifi return resumes paused upload and starts pending rows`
- `startup resumePending respects current connectivity`
- `queue row shows waiting for wifi state` (widget)

## Implementation plan

1. Add dependency; `ConnectivityGate` with constructor params
   `(Stream<List<ConnectivityResult>>? stream, Future<List<ConnectivityResult>> Function()? check)`
   defaulting to the real `Connectivity()` instance.
2. Inject the gate into `UploadQueueProvider`; subscribe in its
   constructor, cancel in `dispose()`.
3. Queue-row widget state text; `flutter test`.
