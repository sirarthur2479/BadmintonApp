import 'package:intl/intl.dart';
import '../models/reflection_data.dart';
import '../models/session.dart';

/// Renders training history as Markdown — the format shared with coaches and
/// fed to AI analysis tooling (kept compatible with the BadmintonTrack-12
/// report format).
class ExportService {
  static final _dateFmt = DateFormat('EEE, d MMM yyyy');

  static String _stars(int n) => '★' * n + '☆' * (5 - n);

  static String sessionToMarkdown(TrainingSession s) {
    final b = StringBuffer()
      ..writeln('## Training Session — ${_dateFmt.format(s.date)}');
    if (s.sessionGoal.isNotEmpty) {
      b
        ..writeln('**Goal:** ${s.sessionGoal}')
        ..writeln(
          '**Duration:** ${s.durationMinutes} min | '
          '**Goal Achievement:** ${_stars(s.goalAchievementScore)}',
        );
    } else if (s.intensity != null) {
      b.writeln(
        '**Duration:** ${s.durationMinutes} min | '
        '**Intensity:** ${s.intensity}/5',
      );
    } else {
      b.writeln('**Duration:** ${s.durationMinutes} min');
    }
    b.writeln();
    if (s.drills.isNotEmpty) {
      b
        ..writeln('**Drills:** ${s.drills.join(', ')}')
        ..writeln();
    }

    final answers = decodeReflectionAnswers(s.reflectionAnswersJson);
    if (answers.isNotEmpty) {
      b.writeln('### Reflection');
      for (var i = 0; i < answers.length; i++) {
        b.writeln('${i + 1}. ${answers[i].questionKey} ${answers[i].answer}');
      }
      b.writeln();
    }

    if (s.playerRemarks.isNotEmpty) {
      b.writeln('**Done Well (Player):** ${s.playerRemarks}');
    }
    if (s.coachRemarks.isNotEmpty) {
      b.writeln('**Coach Remarks:** ${s.coachRemarks}');
    }
    if (s.notes.isNotEmpty) {
      b.writeln('**Notes:** ${s.notes}');
    }
    b
      ..writeln()
      ..writeln('---');
    return b.toString();
  }

  /// Combined Markdown for every session inside [from]..[to] (whole days,
  /// inclusive), oldest first.
  static String bulkExport({
    required List<TrainingSession> sessions,
    required DateTime from,
    required DateTime to,
  }) {
    final fromDay = DateTime(from.year, from.month, from.day);
    final endExclusive =
        DateTime(to.year, to.month, to.day).add(const Duration(days: 1));
    final inRange = sessions
        .where(
          (s) => !s.date.isBefore(fromDay) && s.date.isBefore(endExclusive),
        )
        .toList()
      ..sort((a, b) => a.date.compareTo(b.date));

    final b = StringBuffer()
      ..writeln('# Training Log Export')
      ..writeln(
        '${_dateFmt.format(fromDay)} → ${_dateFmt.format(to)} · '
        '${inRange.length} training sessions',
      )
      ..writeln();
    for (final s in inRange) {
      b.writeln(sessionToMarkdown(s));
    }
    return b.toString();
  }
}
