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
}
