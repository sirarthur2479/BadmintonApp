import 'package:flutter_test/flutter_test.dart';

import 'package:badminton_flutter/models/match_log.dart';
import 'package:badminton_flutter/models/reflection_data.dart';
import 'package:badminton_flutter/models/session.dart';
import 'package:badminton_flutter/services/export_service.dart';

final _full = TrainingSession(
  id: 'export-1',
  date: DateTime(2026, 3, 22),
  durationMinutes: 75,
  drills: const ['Net Play', 'Footwork', 'Drop Shot'],
  sessionGoal: 'Work on net play consistency',
  goalAchievementScore: 4,
  playerRemarks: 'Net kills were sharp',
  coachRemarks: 'Good movement recovery',
  reflectionAnswersJson: encodeReflectionAnswers([
    ReflectionAnswer(
      questionKey: kReflectionQuestions[0],
      answer: 'Lost too many net rallies last match',
    ),
    ReflectionAnswer(
      questionKey: kReflectionQuestions[4],
      answer: 'Add deception to the net kill next session',
    ),
  ]),
);

final _legacy = TrainingSession(
  id: 'export-legacy',
  date: DateTime(2026, 1, 10),
  durationMinutes: 60,
  drills: const ['Smash'],
  intensity: 4,
  notes: 'Old-style session',
);

void main() {
  group('sessionToMarkdown', () {
    test('renders header, goal, duration, stars, and drills', () {
      final md = ExportService.sessionToMarkdown(_full);

      expect(md, contains('## Training Session — Sun, 22 Mar 2026'));
      expect(md, contains('**Goal:** Work on net play consistency'));
      expect(
        md,
        contains('**Duration:** 75 min | **Goal Achievement:** ★★★★☆'),
      );
      expect(md, contains('**Drills:** Net Play, Footwork, Drop Shot'));
      expect(md.trimRight(), endsWith('---'));
    });

    test('numbers only the answered reflection questions', () {
      final md = ExportService.sessionToMarkdown(_full);

      expect(md, contains('### Reflection'));
      expect(
        md,
        contains(
          '1. ${kReflectionQuestions[0]} Lost too many net rallies last match',
        ),
      );
      expect(
        md,
        contains(
          '2. ${kReflectionQuestions[4]} Add deception to the net kill next session',
        ),
      );
      expect(
        md,
        isNot(contains(kReflectionQuestions[1])),
        reason: 'unanswered questions are omitted',
      );
    });

    test('renders remark lines only when non-empty', () {
      final md = ExportService.sessionToMarkdown(_full);
      expect(md, contains('**Done Well (Player):** Net kills were sharp'));
      expect(md, contains('**Coach Remarks:** Good movement recovery'));

      final legacyMd = ExportService.sessionToMarkdown(_legacy);
      expect(legacyMd, isNot(contains('**Done Well (Player):**')));
      expect(legacyMd, isNot(contains('**Coach Remarks:**')));
      expect(legacyMd, isNot(contains('### Reflection')));
    });

    test(
      'legacy session with empty goal and null intensity exports cleanly',
      () {
        final md = ExportService.sessionToMarkdown(_legacy);

        expect(md, contains('## Training Session — Sat, 10 Jan 2026'));
        expect(
          md,
          isNot(contains('**Goal:**')),
          reason: 'no goal line when the session has no goal',
        );
        expect(md, contains('**Duration:** 60 min'));
        expect(md, contains('**Notes:** Old-style session'));
      },
    );
  });

  group('bulkExport', () {
    List<TrainingSession> sessions() => [
      _full, // 2026-03-22
      _legacy, // 2026-01-10
      TrainingSession(
        id: 'export-3',
        date: DateTime(2026, 3, 1),
        durationMinutes: 45,
        drills: const ['Serve'],
        sessionGoal: 'Serve accuracy',
        goalAchievementScore: 2,
      ),
    ];

    test('filters by inclusive date range and reports count', () {
      final md = ExportService.bulkExport(
        sessions: sessions(),
        from: DateTime(2026, 3, 1),
        to: DateTime(2026, 3, 22),
      );

      expect(md, contains('2 training sessions'));
      expect(md, contains('Serve accuracy'));
      expect(md, contains('Work on net play consistency'));
      expect(md, isNot(contains('Old-style session')));
    });

    test('orders sessions chronologically, oldest first', () {
      final md = ExportService.bulkExport(
        sessions: sessions(),
        from: DateTime(2026, 1, 1),
        to: DateTime(2026, 12, 31),
      );

      final legacyIdx = md.indexOf('Sat, 10 Jan 2026');
      final serveIdx = md.indexOf('Serve accuracy');
      final netIdx = md.indexOf('Work on net play consistency');
      expect(legacyIdx, lessThan(serveIdx));
      expect(serveIdx, lessThan(netIdx));
    });

    test('empty range returns a header with zero count', () {
      final md = ExportService.bulkExport(
        sessions: sessions(),
        from: DateTime(2027, 1, 1),
        to: DateTime(2027, 2, 1),
      );

      expect(md, contains('0 training sessions'));
      expect(md, isNot(contains('## Training Session')));
    });
  });

  group('matchLogToMarkdown', () {
    final fullLog = MatchLog(
      id: 'ml-1',
      date: DateTime(2026, 7, 12),
      opponent: 'Ken T.',
      eventContext: 'League round 3',
      scores: '21-15, 18-21, 21-19',
      isWin: true,
      gameplan: 'Attack the backhand',
      readinessScore: 4,
      performanceNotes: 'Smash landed; net play broke down',
      keyMoments: 'Saved 2 game points',
      videoRef: '/videos/league-r3.mp4',
    );

    test('renders header, result line with W and scores', () {
      final md = ExportService.matchLogToMarkdown(fullLog);

      expect(md, contains('## Match — Sun, 12 Jul 2026 vs Ken T.'));
      expect(md, contains('**Result:** Win (21-15, 18-21, 21-19)'));
      expect(md, contains('**Event:** League round 3'));
    });

    test('loss renders as Loss', () {
      final md = ExportService.matchLogToMarkdown(
        fullLog.copyWith(isWin: false),
      );

      expect(md, contains('**Result:** Loss (21-15, 18-21, 21-19)'));
    });

    test('renders readiness as five-slot stars', () {
      final md = ExportService.matchLogToMarkdown(fullLog);

      expect(md, contains('**Readiness:** ★★★★☆'));
    });

    test('renders gameplan, notes, key moments, and video reference', () {
      final md = ExportService.matchLogToMarkdown(fullLog);

      expect(md, contains('**Gameplan:** Attack the backhand'));
      expect(
        md,
        contains('**Performance:** Smash landed; net play broke down'),
      );
      expect(md, contains('**Key Moments:** Saved 2 game points'));
      expect(md, contains('**Video:** /videos/league-r3.mp4'));
    });

    test('omits empty optional sections instead of blank headings', () {
      final bare = MatchLog(
        id: 'ml-2',
        date: DateTime(2026, 7, 12),
        opponent: 'Mia W.',
        isWin: false,
      );

      final md = ExportService.matchLogToMarkdown(bare);

      expect(md, contains('**Result:** Loss'));
      expect(md, isNot(contains('**Event:**')));
      expect(md, isNot(contains('**Gameplan:**')));
      expect(md, isNot(contains('**Performance:**')));
      expect(md, isNot(contains('**Key Moments:**')));
      expect(md, isNot(contains('**Video:**')));
      expect(md, isNot(contains('()')), reason: 'no empty scores parens');
    });
  });

  group('bulkExportMatchLogs', () {
    test('lists logs newest first under one header', () {
      final older = MatchLog(
        id: 'old',
        date: DateTime(2026, 7, 1),
        opponent: 'Older Opponent',
        isWin: true,
      );
      final newer = MatchLog(
        id: 'new',
        date: DateTime(2026, 7, 10),
        opponent: 'Newer Opponent',
        isWin: false,
      );

      final md = ExportService.bulkExportMatchLogs(logs: [older, newer]);

      expect(md, contains('# Match Log Export'));
      expect(md, contains('2 match logs'));
      final newerIdx = md.indexOf('Newer Opponent');
      final olderIdx = md.indexOf('Older Opponent');
      expect(newerIdx, greaterThanOrEqualTo(0));
      expect(newerIdx, lessThan(olderIdx), reason: 'newest first');
    });

    test('empty list still produces the header', () {
      final md = ExportService.bulkExportMatchLogs(logs: const []);

      expect(md, contains('# Match Log Export'));
      expect(md, contains('0 match logs'));
    });
  });
}
