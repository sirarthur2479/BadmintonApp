# Plan: Improve Log Session Feature

## Context

Expanding the app's logging capability in two directions: (1) improve training session logs with goal-setting, structured reflection, and custom drill tags; (2) add a new Match Log record type with pre/post-match review and video referencing. Plus session editing and Markdown export for AI analysis.

---

## Part A: Training Session Improvements

### A1 — New model: `lib/models/reflection_data.dart`

```dart
const List<String> kReflectionQuestions = [
  'Why did you set this goal for today?',
  'Why did you choose these drills?',
  'Why did certain parts feel harder or easier than expected?',
  'How did you apply coaching feedback during the session?',
  'How will you build on today in your next training?',
  'How close did you come to your goal, and what held you back?',
];
```

```dart
class ReflectionAnswer { final String questionKey; final String answer; }
class ReflectionData {
  final int goalAchievementScore;   // 1–5, replaces intensity
  final String playerRemarks;       // "Done Well" — player perspective
  final String coachRemarks;        // "Done Well" — coach perspective
  final List<ReflectionAnswer> answers;  // 6 answers, serialized as JSON string
}
```

### A2 — Updated `lib/models/session.dart`

New fields (all with defaults for backward-compatible `fromMap`):
- `String sessionGoal` (default `''`)
- `int goalAchievementScore` (default `3`)
- `String playerRemarks` (default `''`)
- `String coachRemarks` (default `''`)
- `String reflectionAnswersJson` (default `'[]'`)
- Change `int intensity` → `int? intensity` (legacy rows keep value; new rows `null`)
- Keep `durationMinutes` — stored and shown in history, hidden by default in log form

### A3 — Session editing

- `LogSessionScreen` receives an optional `TrainingSession? session` parameter
- If non-null: populate all state fields from existing session, change button to "Update"
- Add `updateSession(TrainingSession)` to `DatabaseService` (SQL `UPDATE`) and `SessionProvider`
- Add edit `IconButton` to `SessionCard` (alongside existing delete icon)

---

## Part B: Match Log (New Record Type)

### B1 — New model: `lib/models/match_log.dart`

```dart
class MovePerformance {
  final String moveName;   // e.g. 'Service', 'Net Play', etc.
  final int score;         // 1–5
  final String notes;
}

class VideoReference {
  final String id;
  final String label;          // user-given name
  final String path;           // local file path (mobile) or URL (web)
  final DateTime addedAt;
}

class MatchLog {
  final String id;
  final DateTime date;

  // Pre-match
  final String opponentName;
  final String opponentNotes;      // known style, weaknesses
  final String gameplan;           // free-text tactics
  final String targetedAreas;      // what from recent training to execute
  final int mentalReadiness;       // 1–5
  final int physicalReadiness;     // 1–5

  // Post-match
  final String? score;             // optional (e.g. "21-18, 15-21, 21-19")
  final List<MovePerformance> movePerformances;   // 8 key moves, serialized as JSON
  final bool? strategyWorked;      // true/false/null (null = partially)
  final String strategyReview;     // did game plan work? what changed?
  final String keyTurningPoints;
  final String criticalReview;     // overall post-match critical review
  final int overallPerformance;    // 1–5
  final String nextFocus;          // what to work on next

  // Videos
  final List<VideoReference> videos;  // serialized as JSON
}
```

**8 Key Move categories for `MovePerformance`:**
```dart
const List<String> kKeyMoves = [
  'Service', 'Return of Service', 'Net Play', 'Smash',
  'Drop Shot', 'Clear / Lift', 'Defense', 'Footwork',
];
```

### B2 — New DB table in `lib/services/database_service.dart`

```sql
CREATE TABLE match_logs (
  id TEXT PRIMARY KEY,
  date TEXT NOT NULL,
  opponentName TEXT NOT NULL DEFAULT '',
  opponentNotes TEXT NOT NULL DEFAULT '',
  gameplan TEXT NOT NULL DEFAULT '',
  targetedAreas TEXT NOT NULL DEFAULT '',
  mentalReadiness INTEGER NOT NULL DEFAULT 3,
  physicalReadiness INTEGER NOT NULL DEFAULT 3,
  score TEXT,
  movePerformancesJson TEXT NOT NULL DEFAULT '[]',
  strategyWorked INTEGER,   -- 1=yes, 0=no, NULL=partially
  strategyReview TEXT NOT NULL DEFAULT '',
  keyTurningPoints TEXT NOT NULL DEFAULT '',
  criticalReview TEXT NOT NULL DEFAULT '',
  overallPerformance INTEGER NOT NULL DEFAULT 3,
  nextFocus TEXT NOT NULL DEFAULT '',
  videosJson TEXT NOT NULL DEFAULT '[]'
);
```

Add CRUD: `getMatchLogs()`, `insertMatchLog()`, `updateMatchLog()`, `deleteMatchLog()`.

### B3 — New provider: `lib/providers/match_log_provider.dart`

- `ChangeNotifier` with `List<MatchLog> _logs`, lazy-load from DB
- Methods: `loadLogs()`, `addLog()`, `updateLog()`, `deleteLog()`
- Computed: `logsThisMonth`, `avgPerformancePerWeek(weeks: 8)`

Register in `lib/main.dart` alongside existing providers.

### B4 — New screens

**`lib/screens/train/log_match_screen.dart`** — Two-phase form:
- **Phase 1: Pre-Match tab**
  - Opponent name + notes
  - Game plan (free text)
  - Targeted areas from recent training
  - Mental readiness score (1–5 stars)
  - Physical readiness score (1–5 stars)
  - Videos section (add reference)
- **Phase 2: Post-Match tab** (same screen, tab or scroll continuation)
  - Score (optional text field)
  - 8 move performance ratings (star score + notes for each)
  - Strategy review (worked? + notes)
  - Key turning points
  - Critical review (free text)
  - Overall performance score (1–5 stars)
  - Next focus (what to train)
  - Videos section (add more)
- Supports edit mode (pass existing `MatchLog?`)

**`lib/widgets/match_log_card.dart`** — Card for history list showing:
- Date + opponent name
- Overall performance stars
- Score (if set)
- Snippet of critical review
- Edit + delete actions

### B5 — Video referencing

**Package to add:** `open_file: ^3.3.0` (opens local files with system viewer)

Video add flow:
1. User taps "Add Video" → bottom sheet with two options:
   - "Pick from Photos" → `image_picker.pickVideo()` → get local path
   - "Add URL" (web/link) → text input dialog
2. User gives the video a label (e.g., "Set 1 match play")
3. Stored as `VideoReference` in `videosJson`

Tap to open:
- Local path: `OpenFile.open(path)` (opens iPhone Photos/Files viewer)
- URL: `url_launcher` `launchUrl(uri)` (already likely in app or trivial to add)

---

## Part C: Updated Session History Screen

**File:** `lib/screens/train/session_history_screen.dart`

- Add a filter toggle at top: **All | Training | Match**
- Combine training sessions and match logs into a unified chronological list
- Training items render `SessionCard`, match items render `MatchLogCard`
- Each card has edit + delete actions

---

## Part D: LogSessionScreen Redesign (Training)

**File:** `lib/screens/train/log_session_screen.dart`

Section order (scrollable):
1. **Date**
2. **Session Goal** — `TextField`
3. **Drills Practiced** — existing chips + `ActionChip(+, 'New tag')` for custom tags; long-press custom tag to delete
4. **Reflection**:
   - 6 fixed questions (`kReflectionQuestions`), each with 3-line `TextField`
   - Goal Achievement Score — 5-star widget (replaces intensity slider)
   - Player Remarks — `TextField`
   - Coach Remarks — `TextField`
5. **Advanced** (collapsed `ExpansionTile`) — Duration slider
6. **Photos** — existing photo picker
7. **Save / Update button**

Validation: require `sessionGoal` non-empty + at least one drill.

---

## Part E: Export Feature

### E1 — Export service: `lib/services/export_service.dart`

```dart
class ExportService {
  static String sessionToMarkdown(TrainingSession s) { ... }
  static String matchLogToMarkdown(MatchLog m) { ... }
  static String bulkExport({
    required List<TrainingSession> sessions,
    required List<MatchLog> matchLogs,
    required DateTime from,
    required DateTime to,
  }) { ... }
}
```

Markdown format for training session:
```markdown
## Training Session — Mon, 22 Mar 2026
**Goal:** Work on net play consistency
**Duration:** 75 min | **Goal Achievement:** ★★★★☆

**Drills:** Net Play, Footwork, Drop Shot

### Reflection
1. Why did you set this goal? ...
2. Why did you choose these drills? ...
[...6 answers...]

**Done Well (Player):** Net kills were sharp
**Coach Remarks:** Good movement recovery

---
```

Markdown format for match log:
```markdown
## Match — Tue, 23 Mar 2026 vs. John Smith
**Score:** 21-18, 18-21, 21-19 | **Overall:** ★★★★☆

### Pre-Match
**Game Plan:** Attack backhand, use deceptive drops at net
**Mental:** ★★★★☆ | **Physical:** ★★★★★

### Move Performance
| Move | Score | Notes |
|------|-------|-------|
| Service | ★★★☆☆ | Low serve was inconsistent |
...

### Post-Match Review
**Strategy worked?** Partially
**Key turning points:** ...
**Critical review:** ...
**Next focus:** ...

---
```

### E2 — Single log export

- Add share `IconButton` to `LogSessionScreen` app bar (edit mode) and `LogMatchScreen`
- Calls `ExportService.sessionToMarkdown()` or `matchLogToMarkdown()`
- Uses `Share.shareXFiles()` — add `share_plus: ^7.0.0` to pubspec

### E3 — Bulk export screen: `lib/screens/export_screen.dart`

- Date range picker (from / to)
- Checkboxes: include Training Sessions, include Match Logs
- Preview count: "12 sessions, 3 matches in range"
- "Export as Markdown" button → generates combined Markdown → share sheet
- Access from Profile screen or a menu in Session History

---

## Database Migration Summary

**File:** `lib/services/database_service.dart`

- Version **1 → 2**
- `onUpgrade` adds 5 columns to `sessions`, creates `custom_tags` and `match_logs` tables
- `onCreate` includes all tables and columns from the start (fresh install)
- Add `updateSession(TrainingSession)` SQL UPDATE method

---

## Updated Provider

**File:** `lib/providers/session_provider.dart`

- Add `updateSession(TrainingSession)` method
- Add custom tags CRUD (`addCustomTag`, `deleteCustomTag`, `loadCustomTags`)
- Add `allDrillTypes` getter: `[...kDrillTypes, ..._customTags]`
- Add `avgGoalAchievementPerWeek({int weeks = 8})`

---

## Theme + Widget Updates

**`lib/theme/app_theme.dart`:** Add `goalScoreColor(int score)` static method.

**`lib/widgets/session_card.dart`:**
- Remove `_IntensityDots`
- Add goal achievement stars badge
- Add `sessionGoal` line, `playerRemarks` line, `coachRemarks` line
- Add edit button alongside delete

**`lib/widgets/goal_achievement_chart.dart`** (new): `BarChart` using `avgGoalAchievementPerWeek`, 8 weeks, colored by `goalScoreColor`.

**`lib/screens/home/home_screen.dart`:**
- Last session card: replace intensity with goal achievement score + goal text
- Add Goal Achievement Trend chart section

---

## New Dependencies to Add (`pubspec.yaml`)

```yaml
open_file: ^3.3.0       # open local video/files with system viewer
share_plus: ^7.0.0      # share Markdown export via share sheet
```

`url_launcher` — check if already present; add if not (for URL-based videos).

---

## Implementation Order

**Phase 1 — Foundation (no UI yet)**
1. `lib/models/reflection_data.dart` — new
2. `lib/models/session.dart` — extend with new fields
3. `lib/models/match_log.dart` — new
4. `lib/services/database_service.dart` — version bump, migration, match_logs table, custom_tags, updateSession
5. `lib/providers/session_provider.dart` — custom tags, updateSession, avgGoalAchievementPerWeek
6. `lib/providers/match_log_provider.dart` — new
7. `lib/main.dart` — register new provider
8. `pubspec.yaml` — add open_file, share_plus

**Phase 2 — Theme + Widgets**
9. `lib/theme/app_theme.dart` — goalScoreColor
10. `lib/widgets/session_card.dart` — new display fields, edit button
11. `lib/widgets/match_log_card.dart` — new
12. `lib/widgets/goal_achievement_chart.dart` — new

**Phase 3 — Screens**
13. `lib/screens/train/log_session_screen.dart` — full redesign + edit mode
14. `lib/screens/train/log_match_screen.dart` — new
15. `lib/screens/train/session_history_screen.dart` — unified list with filter toggle
16. `lib/screens/home/home_screen.dart` — last session + chart updates
17. `lib/screens/export_screen.dart` — new
18. `lib/app.dart` — add route for export screen

**Phase 4 — Export**
19. `lib/services/export_service.dart` — new
20. Wire share buttons into LogSessionScreen and LogMatchScreen

**Phase 5 — Seed data cleanup**
21. `lib/data/sample_sessions_seed.dart` — add sample goals/reflections for a few sessions

---

## Verification

1. **Fresh install** — all tables created correctly; log a training session with goal + reflection + custom tag; log a match with pre/post sections and video; verify history shows both types with filter toggle.
2. **Upgrade from v1** — old seeded sessions display gracefully (empty goal, ★3/5 default, no crash).
3. **Edit session** — open existing training session in edit mode, modify goal, save; verify updated in history.
4. **Custom tags** — create tag, persists after restart; long-press to delete.
5. **Video reference** — pick video from Photos, tap to open in system viewer; add URL, tap to launch.
6. **Single export** — share a training session as Markdown; verify format is clean and AI-readable.
7. **Bulk export** — select 2-week date range including both session types; verify combined Markdown covers all logs chronologically.
8. **Goal Achievement Chart** — 8-week bar chart renders on home screen.
