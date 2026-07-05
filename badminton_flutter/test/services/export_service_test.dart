import 'package:flutter_test/flutter_test.dart';

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
      expect(md,
          contains('**Duration:** 75 min | **Goal Achievement:** ★★★★☆'));
      expect(md, contains('**Drills:** Net Play, Footwork, Drop Shot'));
      expect(md.trimRight(), endsWith('---'));
    });

    test('numbers only the answered reflection questions', () {
      final md = ExportService.sessionToMarkdown(_full);

      expect(md, contains('### Reflection'));
      expect(
          md,
          contains(
              '1. ${kReflectionQuestions[0]} Lost too many net rallies last match'));
      expect(
          md,
          contains(
              '2. ${kReflectionQuestions[4]} Add deception to the net kill next session'));
      expect(md, isNot(contains(kReflectionQuestions[1])),
          reason: 'unanswered questions are omitted');
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

    test('legacy session with empty goal and null intensity exports cleanly',
        () {
      final md = ExportService.sessionToMarkdown(_legacy);

      expect(md, contains('## Training Session — Sat, 10 Jan 2026'));
      expect(md, isNot(contains('**Goal:**')),
          reason: 'no goal line when the session has no goal');
      expect(md, contains('**Duration:** 60 min'));
      expect(md, contains('**Notes:** Old-style session'));
    });
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
}
