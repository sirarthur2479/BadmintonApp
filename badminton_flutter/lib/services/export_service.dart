import 'dart:io';

import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:intl/intl.dart';
import '../models/reflection_data.dart';
import '../models/session.dart';

/// Renders training history as Markdown — the format shared with coaches and
/// fed to AI analysis tooling (kept compatible with the BadmintonTrack-12
/// report format).
class ExportService {
  static final _dateFmt = DateFormat('EEE, d MMM yyyy');

  static String _stars(int n) => '★' * n + '☆' * (5 - n);

  static String sessionToMarkdown(
    TrainingSession s, {
    String? analysisReport,
  }) {
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
    if (analysisReport != null && analysisReport.isNotEmpty) {
      b
        ..writeln()
        ..writeln('### BadmintonTrack Coach Report')
        ..writeln(analysisReport);
    }
    b
      ..writeln()
      ..writeln('---');
    return b.toString();
  }

  /// Reads each session's downloaded coach report off disk, keyed by
  /// session id. Mobile-only artifacts: on web (or when nothing is
  /// attached) this is simply empty.
  static Map<String, String> loadAnalysisReports(
    List<TrainingSession> sessions,
  ) {
    if (kIsWeb) return const {};
    final reports = <String, String>{};
    for (final s in sessions) {
      final path = s.analysisReportPath;
      if (path == null) continue;
      final file = File(path);
      if (file.existsSync()) reports[s.id] = file.readAsStringSync();
    }
    return reports;
  }

  /// Combined Markdown for every session inside [from]..[to] (whole days,
  /// inclusive), oldest first.
  static String bulkExport({
    required List<TrainingSession> sessions,
    required DateTime from,
    required DateTime to,
    Map<String, String> analysisReports = const {}, // by session id
  }) {
    final fromDay = DateTime(from.year, from.month, from.day);
    final endExclusive = DateTime(
      to.year,
      to.month,
      to.day,
    ).add(const Duration(days: 1));
    final inRange =
        sessions
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
      b.writeln(sessionToMarkdown(s, analysisReport: analysisReports[s.id]));
    }
    return b.toString();
  }
}
