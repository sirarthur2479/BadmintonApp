import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:badminton_flutter/models/session.dart';
import 'package:badminton_flutter/widgets/session_card.dart';

final _session = TrainingSession(
  id: 'card-1',
  date: DateTime(2026, 7, 3),
  durationMinutes: 60,
  drills: const ['Footwork'],
  intensity: 3,
);

Widget _app(Widget child) => MaterialApp(home: Scaffold(body: child));

void main() {
  testWidgets('shows edit icon only when onEdit provided', (tester) async {
    await tester.pumpWidget(_app(SessionCard(session: _session)));
    expect(find.byIcon(Icons.edit_outlined), findsNothing);

    await tester.pumpWidget(
      _app(SessionCard(session: _session, onEdit: () {})),
    );
    expect(find.byIcon(Icons.edit_outlined), findsOneWidget);
  });

  testWidgets('tapping the edit icon invokes onEdit', (tester) async {
    var edited = false;
    await tester.pumpWidget(
      _app(
        SessionCard(
          session: _session,
          onEdit: () => edited = true,
          onDelete: () {},
        ),
      ),
    );

    await tester.tap(find.byIcon(Icons.edit_outlined));

    expect(edited, isTrue);
  });

  testWidgets('edit and delete icons coexist on the card', (tester) async {
    await tester.pumpWidget(
      _app(SessionCard(session: _session, onEdit: () {}, onDelete: () {})),
    );

    expect(find.byIcon(Icons.edit_outlined), findsOneWidget);
    expect(find.byIcon(Icons.delete_outline), findsOneWidget);
  });

  group('goal display', () {
    final goalSession = TrainingSession(
      id: 'card-goal',
      date: DateTime(2026, 7, 4),
      durationMinutes: 75,
      drills: const ['Net Play'],
      sessionGoal: 'Sharper net kills',
      goalAchievementScore: 4,
      playerRemarks: 'kills were crisp',
      coachRemarks: 'watch recovery',
    );

    testWidgets('shows goal text and star badge when a goal is set',
        (tester) async {
      await tester.pumpWidget(_app(SessionCard(session: goalSession)));

      expect(find.text('Sharper net kills'), findsOneWidget);
      expect(find.byIcon(Icons.star), findsNWidgets(4),
          reason: 'goal achievement 4/5 renders 4 filled stars');
      expect(find.byIcon(Icons.star_border), findsNWidgets(1));
    });

    testWidgets('shows player and coach remarks when non-empty',
        (tester) async {
      await tester.pumpWidget(_app(SessionCard(session: goalSession)));

      expect(find.textContaining('kills were crisp'), findsOneWidget);
      expect(find.textContaining('watch recovery'), findsOneWidget);
    });

    testWidgets('legacy session keeps intensity dots and no goal line',
        (tester) async {
      await tester.pumpWidget(_app(SessionCard(session: _session)));

      expect(find.byIcon(Icons.star), findsNothing,
          reason: 'no stars without a goal-based session');
      expect(find.textContaining('Goal'), findsNothing);
    });

    testWidgets('goalless session with null intensity renders without badges',
        (tester) async {
      final bare = TrainingSession(
        id: 'card-bare',
        date: DateTime(2026, 7, 4),
        durationMinutes: 30,
        drills: const ['Serve'],
      );
      await tester.pumpWidget(_app(SessionCard(session: bare)));

      expect(find.byIcon(Icons.star), findsNothing);
      expect(tester.takeException(), isNull);
    });
  });
}
