# TASK-012 - Goal display: SessionCard fields, home last-session card, achievement chart, seed data

**Use case:** [ideas/use-cases/log-session-part-a.md](../../ideas/use-cases/log-session-part-a.md)
**Research:** - (none required; spec in `badminton_flutter/docs/log-session-improvement-plan.md` "Theme + Widget Updates")
**Depends on:** TASK-009, TASK-011
**Effort:** M
**Risk:** low

**Status:** done

## Goal

Surface the new goal/reflection data everywhere sessions are displayed:
`SessionCard` shows the goal, achievement stars, and remarks instead of
intensity dots; the home screen's last-session card swaps intensity for goal
text + stars and gains an 8-week Goal Achievement Trend bar chart; the theme
gets a `goalScoreColor` scale; and the sample seed data includes goals and
reflections so a demo install exercises the new UI.

## Acceptance criteria

- `AppTheme.goalScoreColor(int score)` static method maps 1–5 to a
  red→green scale (mirroring `intensityColor`'s style).
- `lib/widgets/session_card.dart`: `_IntensityDots` removed; a compact star
  badge shows `goalAchievementScore` colored by `goalScoreColor`; when
  non-empty, a `sessionGoal` line (single line, ellipsized), a
  `playerRemarks` line, and a `coachRemarks` line render; legacy sessions
  (empty goal, default score 3) render without crash or empty gaps.
- `lib/widgets/goal_achievement_chart.dart` (new): `fl_chart` `BarChart`
  fed by `avgGoalAchievementPerWeek(weeks: 8)`, bars colored by
  `goalScoreColor`, y-axis fixed 0–5.
- `lib/screens/home/home_screen.dart`: last-session card shows the goal text
  and star score instead of intensity; a "Goal Achievement Trend" section
  renders the chart.
- `lib/data/sample_sessions_seed.dart`: at least 3 seeded sessions carry a
  `sessionGoal`, varied `goalAchievementScore`, remarks, and one encoded
  reflection answer set; seeded rows keep non-null legacy `intensity`.
- `flutter test` fully green (including the existing `seed_gate_test.dart`).

## Test plan

RED before implementation:

- `test/widgets/session_card_test.dart`:
  - `card shows goal text and star badge when goal set`
  - `card shows player and coach remarks when non-empty`
  - `legacy session (no goal, null intensity) renders without goal line`
- `test/widgets/goal_achievement_chart_test.dart`:
  - `chart renders one bar group per week from provider data`
- `test/theme/app_theme_test.dart` (new):
  - `goalScoreColor returns distinct colors for scores 1 and 5`
- `test/screens/home_screen_test.dart` (new, provider-backed pump):
  - `home shows last session goal and stars`
  - `home shows Goal Achievement Trend section`
- `test/data/seed_gate_test.dart` (extend):
  - `seeded sessions include goals and reflection answers`

## Implementation plan

1. `lib/theme/app_theme.dart`: `static Color goalScoreColor(int score)`.
2. `lib/widgets/session_card.dart`: replace `_IntensityDots` usage with a
   `Row` of small `Icons.star`/`star_border` (reuse `StarRating` read-only or
   a private `_StarBadge`); add conditional goal/remarks `Text` lines.
3. `lib/widgets/goal_achievement_chart.dart`: consume
   `context.watch<SessionProvider>().avgGoalAchievementPerWeek()`; structure
   copied from the existing weekly chart usage in
   `lib/screens/profile/progress_screen.dart` (check before writing).
4. `lib/screens/home/home_screen.dart`: swap intensity display; add chart
   section beneath existing stats.
5. `lib/data/sample_sessions_seed.dart`: enrich 3+ entries via
   `encodeReflectionAnswers`.
6. Full `flutter test`.
