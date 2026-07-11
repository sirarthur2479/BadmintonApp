import 'package:flutter_test/flutter_test.dart';

import 'package:badminton_flutter/models/analysis_job.dart';

void main() {
  test('analysis job json round trip', () {
    final job = AnalysisJob.fromJson(const {
      'id': 'job-1',
      'playerId': 'pl-1',
      'sessionId': 'sess-42',
      'mode': 'footwork',
      'status': 'analyzing',
      'reportPath': null,
      'courtMapPath': null,
      'errorMessage': null,
      'createdAt': '2026-07-08T10:00:00+00:00',
      'startedAt': '2026-07-08T10:00:01+00:00',
      'finishedAt': null,
    });

    expect(job.id, 'job-1');
    expect(job.sessionId, 'sess-42');
    expect(job.mode, 'footwork');
    expect(job.status, AnalysisJobStatus.analyzing);
    expect(job.errorMessage, isNull);
  });

  test('terminal states parse and unknown degrades to failed', () {
    AnalysisJob withStatus(String s) => AnalysisJob.fromJson({
          'id': 'j',
          'sessionId': 's',
          'mode': 'full',
          'status': s,
        });

    expect(withStatus('queued').status, AnalysisJobStatus.queued);
    expect(withStatus('done').status, AnalysisJobStatus.done);
    expect(withStatus('failed').status, AnalysisJobStatus.failed);
    expect(withStatus('who-knows').status, AnalysisJobStatus.failed);
    expect(withStatus('done').isTerminal, isTrue);
    expect(withStatus('queued').isTerminal, isFalse);
  });
}
