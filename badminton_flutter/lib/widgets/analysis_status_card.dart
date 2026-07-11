import 'package:flutter/material.dart';

import '../models/analysis_job.dart';
import '../models/session.dart';
import '../screens/train/analysis_report_screen.dart';

/// Fire-and-forget analysis state for one session. Pure widget: the parent
/// passes the latest known job (from AnalysisStatusProvider). Renders
/// nothing until there is something worth saying.
class AnalysisStatusCard extends StatelessWidget {
  final TrainingSession session;
  final AnalysisJob? job;

  const AnalysisStatusCard({super.key, required this.session, this.job});

  @override
  Widget build(BuildContext context) {
    // A downloaded report beats any live job state.
    if (session.analysisReportPath != null) {
      return Card(
        child: ListTile(
          leading: const Icon(Icons.insights),
          title: const Text('Coach report ready'),
          subtitle: const Text('BadmintonTrack video analysis'),
          onTap: () => Navigator.of(context).push(
            MaterialPageRoute(
              builder: (_) => AnalysisReportScreen(session: session),
            ),
          ),
        ),
      );
    }

    final job = this.job;
    if (job == null) return const SizedBox.shrink();

    return switch (job.status) {
      AnalysisJobStatus.queued => const Card(
          child: ListTile(
            leading: Icon(Icons.hourglass_empty),
            title: Text('Analysis queued on the server'),
          ),
        ),
      AnalysisJobStatus.analyzing => const Card(
          child: ListTile(
            leading: Icon(Icons.query_stats),
            title: Text('Analysing video…'),
            subtitle: Text('This takes a few minutes — check back later'),
          ),
        ),
      AnalysisJobStatus.failed => Card(
          child: ListTile(
            leading: const Icon(Icons.error_outline, color: Colors.red),
            title: const Text('Analysis failed'),
            subtitle: Text(job.errorMessage ?? 'unknown error'),
          ),
        ),
      // done but not yet downloaded: next poll attaches it.
      AnalysisJobStatus.done => const Card(
          child: ListTile(
            leading: Icon(Icons.download),
            title: Text('Analysis done — fetching report'),
          ),
        ),
    };
  }
}
