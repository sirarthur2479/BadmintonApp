import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:badminton_flutter/widgets/star_rating.dart';

Widget _app(Widget child) => MaterialApp(home: Scaffold(body: child));

void main() {
  testWidgets('renders the current value as filled stars', (tester) async {
    await tester.pumpWidget(_app(StarRating(value: 3, onChanged: (_) {})));

    expect(find.byIcon(Icons.star), findsNWidgets(3));
    expect(find.byIcon(Icons.star_border), findsNWidgets(2));
  });

  testWidgets('tapping star N reports value N', (tester) async {
    int? reported;
    await tester.pumpWidget(
      _app(StarRating(value: 1, onChanged: (v) => reported = v)),
    );

    // Stars render left-to-right; the sole filled star is #1, so the last
    // outlined star is #5.
    await tester.tap(find.byIcon(Icons.star_border).last);
    expect(reported, 5);

    await tester.tap(find.byIcon(Icons.star)); // the filled first star
    expect(reported, 1);
  });

  testWidgets('read-only when onChanged is null', (tester) async {
    await tester.pumpWidget(_app(const StarRating(value: 4)));

    await tester.tap(find.byIcon(Icons.star).first);
    await tester.pump();

    expect(
      find.byIcon(Icons.star),
      findsNWidgets(4),
      reason: 'value must not change without a callback',
    );
  });
}
