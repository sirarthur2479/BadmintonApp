# TASK-007 - Session model: JSON drills, reflection model, new goal/reflection fields

**Use case:** [ideas/use-cases/log-session-part-a.md](../../ideas/use-cases/log-session-part-a.md)
**Research:** - (none required; spec in `badminton_flutter/docs/log-session-improvement-plan.md` §A1/A2)
**Depends on:** -
**Effort:** S
**Risk:** low

**Status:** in-progress

## Goal

Extend the pure model layer for Part A: a new `ReflectionData` module with the
six fixed reflection questions and JSON-serializable answers, and an extended
`TrainingSession` with goal/reflection fields, nullable legacy `intensity`,
and — critically — drills stored as a JSON array instead of a comma-joined
string (a custom tag containing a comma must survive the round-trip).
`fromMap` stays tolerant of both legacy formats so pre-migration rows and
old seed maps still parse. No DB or UI changes in this task; only the minimal
null-safety fallout in existing callers so the app still compiles.

## Acceptance criteria

- `lib/models/reflection_data.dart` exists with:
  - `const List<String> kReflectionQuestions` — exactly the 6 questions from the plan doc.
  - `class ReflectionAnswer { final String questionKey; final String answer; }`
    with `toJson()`/`fromJson()`.
  - `String encodeReflectionAnswers(List<ReflectionAnswer> answers)` and
    `List<ReflectionAnswer> decodeReflectionAnswers(String json)`;
    decode returns `[]` for `''`, `'[]'`, or malformed JSON (never throws).
- `TrainingSession` gains `String sessionGoal` (default `''`),
  `int goalAchievementScore` (default `3`), `String playerRemarks` (default `''`),
  `String coachRemarks` (default `''`), `String reflectionAnswersJson`
  (default `'[]'`); `intensity` becomes `int?`; `durationMinutes` unchanged.
  `copyWith` covers all new fields.
- `toMap()` writes `drills` as a JSON array string (`jsonEncode(drills)`).
- `fromMap()` reads drills dual-format: JSON array if the string starts with
  `[`, else legacy comma-split; all new fields default when keys are absent.
- A drill named `Multi-feed, front court` round-trips `toMap` → `fromMap` intact.
- Existing callers compile: `_IntensityDots` renders only when
  `session.intensity != null`, `avgIntensityPerWeek` skips null-intensity
  sessions. No visual redesign yet.
- `flutter test` fully green.

## Test plan

RED before implementation, in `test/models/session_test.dart` (extend) and new
`test/models/reflection_data_test.dart`:

- `session_test.dart`:
  - `drills round-trip preserves a tag containing a comma`
  - `toMap writes drills as a JSON array`
  - `fromMap parses legacy comma-joined drills`
  - `fromMap defaults new fields when keys are missing (legacy map)`
  - `goal and reflection fields survive toMap/fromMap round-trip`
  - `null intensity survives round-trip; non-null legacy intensity preserved`
  - `copyWith replaces each new field independently`
- `reflection_data_test.dart`:
  - `kReflectionQuestions has 6 entries matching the plan wording`
  - `encode/decode reflection answers round-trip`
  - `decodeReflectionAnswers returns empty list for empty and malformed input`

## Implementation plan

1. `lib/models/reflection_data.dart` (new): `kReflectionQuestions`,
   `ReflectionAnswer` (`toJson`, `fromJson`, `==`/`hashCode` optional),
   top-level `encodeReflectionAnswers`/`decodeReflectionAnswers` using
   `dart:convert` with a `try/catch` fallback to `[]`.
2. `lib/models/session.dart`: add fields + defaults to constructor and
   `copyWith`; change `intensity` to `int?`; `toMap`: `'drills': jsonEncode(drills)`,
   add new keys; `fromMap`: `_decodeDrills(String raw)` helper — trimmed string
   starting with `[` → `List<String>.from(jsonDecode(raw))`, else existing
   comma-split; new fields via `map['x'] as T? ?? default`.
3. Minimal caller fixes: `lib/widgets/session_card.dart` — wrap
   `_IntensityDots` in `if (session.intensity != null)`;
   `lib/providers/session_provider.dart` — `avgIntensityPerWeek` filters
   `s.intensity != null` before averaging;
   `lib/screens/train/log_session_screen.dart` and
   `lib/data/sample_sessions_seed.dart` compile unchanged (nullable accepts int).
4. Run `flutter test`; update any TASK-005 round-trip fixtures that assert the
   old comma format (they should now assert JSON — that change is part of the
   RED tests above, not a bypass).
