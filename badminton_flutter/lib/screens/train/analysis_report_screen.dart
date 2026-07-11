import 'dart:io';

import 'package:flutter/material.dart';

import '../../models/session.dart';

/// The BadmintonTrack coach report + court map for one session. The report
/// is Markdown rendered as selectable text (no heavy renderer dependency —
/// coach reports are headings and bullet lists, readable as-is).
class AnalysisReportScreen extends StatelessWidget {
  final TrainingSession session;

  const AnalysisReportScreen({super.key, required this.session});

  @override
  Widget build(BuildContext context) {
    final reportPath = session.analysisReportPath;
    final courtMapPath = session.analysisCourtMapPath;
    final courtMapFile =
        courtMapPath != null ? File(courtMapPath) : null;

    return Scaffold(
      appBar: AppBar(title: const Text('Coach Report')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          if (courtMapFile != null && courtMapFile.existsSync()) ...[
            Image.file(courtMapFile),
            const SizedBox(height: 16),
          ],
          SelectableText(
            reportPath != null && File(reportPath).existsSync()
                ? File(reportPath).readAsStringSync()
                : 'Report file is missing.',
            style: const TextStyle(height: 1.5),
          ),
        ],
      ),
    );
  }
}
