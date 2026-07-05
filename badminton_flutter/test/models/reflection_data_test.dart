import 'package:flutter_test/flutter_test.dart';
import 'package:badminton_flutter/models/reflection_data.dart';

void main() {
  group('kReflectionQuestions', () {
    test('has 6 entries matching the plan wording', () {
      expect(kReflectionQuestions, hasLength(6));
      expect(kReflectionQuestions, const [
        'Why did you set this goal for today?',
        'Why did you choose these drills?',
        'Why did certain parts feel harder or easier than expected?',
        'How did you apply coaching feedback during the session?',
        'How will you build on today in your next training?',
        'How close did you come to your goal, and what held you back?',
      ]);
    });
  });

  group('encode/decode reflection answers', () {
    test('round-trip preserves question keys and answers', () {
      final answers = [
        ReflectionAnswer(
          questionKey: kReflectionQuestions[0],
          answer: 'Coach said footwork first',
        ),
        ReflectionAnswer(
          questionKey: kReflectionQuestions[3],
          answer: 'Kept racket up between shots, like he said',
        ),
      ];

      final decoded = decodeReflectionAnswers(encodeReflectionAnswers(answers));

      expect(decoded, hasLength(2));
      expect(decoded[0].questionKey, kReflectionQuestions[0]);
      expect(decoded[0].answer, 'Coach said footwork first');
      expect(decoded[1].questionKey, kReflectionQuestions[3]);
      expect(decoded[1].answer, 'Kept racket up between shots, like he said');
    });

    test('encode of empty list is a JSON empty array', () {
      expect(encodeReflectionAnswers(const []), '[]');
    });

    test('decode returns empty list for empty and malformed input', () {
      expect(decodeReflectionAnswers(''), isEmpty);
      expect(decodeReflectionAnswers('[]'), isEmpty);
      expect(decodeReflectionAnswers('not json at all'), isEmpty);
      expect(decodeReflectionAnswers('{"oops": true}'), isEmpty);
      expect(decodeReflectionAnswers('[{"missing": "keys"}]'), isEmpty);
    });

    test('answers containing commas and quotes survive the round-trip', () {
      final answers = [
        ReflectionAnswer(
          questionKey: kReflectionQuestions[1],
          answer: 'Smash, drop, then "deception" drills — in that order',
        ),
      ];

      final decoded = decodeReflectionAnswers(encodeReflectionAnswers(answers));

      expect(
        decoded.single.answer,
        'Smash, drop, then "deception" drills — in that order',
      );
    });
  });
}
