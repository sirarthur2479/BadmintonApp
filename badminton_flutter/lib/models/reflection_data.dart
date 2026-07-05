import 'dart:convert';

/// The six fixed reflection questions asked after every training session.
const List<String> kReflectionQuestions = [
  'Why did you set this goal for today?',
  'Why did you choose these drills?',
  'Why did certain parts feel harder or easier than expected?',
  'How did you apply coaching feedback during the session?',
  'How will you build on today in your next training?',
  'How close did you come to your goal, and what held you back?',
];

class ReflectionAnswer {
  final String questionKey;
  final String answer;

  const ReflectionAnswer({required this.questionKey, required this.answer});

  Map<String, dynamic> toJson() => {
        'questionKey': questionKey,
        'answer': answer,
      };

  factory ReflectionAnswer.fromJson(Map<String, dynamic> json) {
    return ReflectionAnswer(
      questionKey: json['questionKey'] as String,
      answer: json['answer'] as String,
    );
  }
}

String encodeReflectionAnswers(List<ReflectionAnswer> answers) {
  return jsonEncode(answers.map((a) => a.toJson()).toList());
}

/// Decodes a JSON answer list; malformed input yields an empty list rather
/// than throwing, so a corrupt DB row can never crash a screen.
List<ReflectionAnswer> decodeReflectionAnswers(String json) {
  if (json.isEmpty) return [];
  try {
    final raw = jsonDecode(json);
    if (raw is! List) return [];
    return raw
        .map((e) => ReflectionAnswer.fromJson(e as Map<String, dynamic>))
        .toList();
  } catch (_) {
    return [];
  }
}
