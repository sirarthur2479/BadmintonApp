import 'package:flutter_test/flutter_test.dart';
import 'package:badminton_trainer/models/match_log.dart';

void main() {
  group('MatchLog map round-trip', () {
    final full = MatchLog(
      id: 'log-1',
      date: DateTime(2026, 7, 12, 14, 30),
      opponent: 'Ken T.',
      eventContext: 'League round 3',
      scores: '21-15, 18-21, 21-19',
      isWin: true,
      gameplan: 'Attack the backhand, keep rallies short',
      readinessScore: 4,
      performanceNotes: 'Smash landed; net play broke down in game 2',
      keyMoments: 'Saved 2 game points at 18-20 in the decider',
      videoRef: '/videos/league-r3.mp4',
    );

    test('toMap/fromMap round-trips a fully-populated log', () {
      final restored = MatchLog.fromMap(full.toMap());

      expect(restored.id, full.id);
      expect(restored.date, full.date);
      expect(restored.opponent, full.opponent);
      expect(restored.eventContext, full.eventContext);
      expect(restored.scores, full.scores);
      expect(restored.isWin, full.isWin);
      expect(restored.gameplan, full.gameplan);
      expect(restored.readinessScore, full.readinessScore);
      expect(restored.performanceNotes, full.performanceNotes);
      expect(restored.keyMoments, full.keyMoments);
      expect(restored.videoRef, full.videoRef);
    });

    test('toMap encodes isWin true as 1 and false as 0', () {
      expect(full.toMap()['isWin'], 1);
      final loss = MatchLog(
        id: 'log-2',
        date: DateTime(2026, 7, 12),
        opponent: 'Mia W.',
        isWin: false,
      );
      expect(loss.toMap()['isWin'], 0);
    });

    test('toMap encodes date as ISO-8601 string and fromMap parses it back',
        () {
      final map = full.toMap();
      expect(map['date'], '2026-07-12T14:30:00.000');
      expect(MatchLog.fromMap(map).date, DateTime(2026, 7, 12, 14, 30));
    });
  });
}
