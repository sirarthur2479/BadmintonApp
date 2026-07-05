import 'package:flutter_test/flutter_test.dart';

import 'package:badminton_flutter/theme/app_theme.dart';

void main() {
  group('goalScoreColor', () {
    test('covers all five scores', () {
      for (var score = 1; score <= 5; score++) {
        expect(AppTheme.goalScoreColor(score), isNotNull);
      }
    });

    test('low and high scores get distinct colors', () {
      expect(AppTheme.goalScoreColor(1), isNot(AppTheme.goalScoreColor(5)));
      expect(AppTheme.goalScoreColor(1), isNot(AppTheme.goalScoreColor(3)));
    });
  });
}
