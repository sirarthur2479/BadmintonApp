import 'package:flutter_test/flutter_test.dart';

import 'package:badminton_flutter/utils/streak.dart';

DateTime d(int day) => DateTime(2026, 7, day);

void main() {
  final today = d(10);

  group('currentStreak', () {
    test('counts consecutive days ending today', () {
      expect(currentStreak([d(10), d(9), d(8)], today), 3);
    });

    test('counts a run ending yesterday', () {
      expect(currentStreak([d(9), d(8)], today), 2);
    });

    test('is 0 when last session is 2+ days ago', () {
      expect(currentStreak([d(7), d(6)], today), 0);
    });

    test('multiple sessions on one day count once', () {
      expect(
        currentStreak([d(10), DateTime(2026, 7, 10, 18), d(9)], today),
        2,
      );
    });

    test('is 0 for no sessions', () {
      expect(currentStreak(const [], today), 0);
    });
  });

  group('bestStreak', () {
    test('finds the longest historical run', () {
      // 5-day run (1-5), gap, 2-day run (8-9).
      expect(bestStreak([d(1), d(2), d(3), d(4), d(5), d(8), d(9)]), 5);
    });

    test('equals currentStreak when the current run is the longest', () {
      final dates = [d(8), d(9), d(10), d(1), d(2)];
      expect(bestStreak(dates), currentStreak(dates, today));
    });

    test('is 0 for no sessions', () {
      expect(bestStreak(const []), 0);
    });
  });
}
