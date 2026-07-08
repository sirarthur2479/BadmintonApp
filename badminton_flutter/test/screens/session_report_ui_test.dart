import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:badminton_flutter/models/analysis_job.dart';
import 'package:badminton_flutter/models/session.dart';
import 'package:badminton_flutter/screens/train/analysis_report_screen.dart';
import 'package:badminton_flutter/services/export_service.dart';
import 'package:badminton_flutter/widgets/analysis_status_card.dart';

// 1x1 transparent PNG.
final _pngBytes = base64Decode(
  'iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAYAAAAfFcSJAAAADUlEQVR42mNk'
  'YPhfDwAChwGA60e6kgAAAABJRU5ErkJggg==',
);

TrainingSession _session({String? reportPath, String? courtMapPath}) =>
    TrainingSession(
      id: 'sess-42',
      date: DateTime(2026, 7, 8),
      durationMinutes: 60,
      drills: const ['Smash'],
      analysisReportPath: reportPath,
      analysisCourtMapPath: courtMapPath,
    );

AnalysisJob _job(AnalysisJobStatus status, {String? error}) => AnalysisJob(
      id: 'job-1',
      sessionId: 'sess-42',
      mode: 'footwork',
      status: status,
      errorMessage: error,
    );

Widget _app(Widget child) => MaterialApp(home: Scaffold(body: child));

void main() {
  testWidgets('status card walks queued analyzing done', (tester) async {
    await tester.pumpWidget(_app(AnalysisStatusCard(
      session: _session(),
      job: _job(AnalysisJobStatus.queued),
    )));
    expect(find.textContaining('queued'), findsOneWidget);

    await tester.pumpWidget(_app(AnalysisStatusCard(
      session: _session(),
      job: _job(AnalysisJobStatus.analyzing),
    )));
    expect(find.textContaining('Analysing'), findsOneWidget);

    final report = File(
        '${Directory.systemTemp.path}/report_ui_done.md')
      ..writeAsStringSync('# Coach Report');
    await tester.pumpWidget(_app(AnalysisStatusCard(
      session: _session(reportPath: report.path),
      job: null, // once attached, no live job needed
    )));
    expect(find.textContaining('Coach report'), findsOneWidget);
  });

  testWidgets('nothing renders without a job or report', (tester) async {
    await tester.pumpWidget(_app(AnalysisStatusCard(
      session: _session(),
      job: null,
    )));

    expect(find.byType(Card), findsNothing);
    expect(find.byType(ListTile), findsNothing);
  });

  testWidgets('failed card shows the server error message', (tester) async {
    await tester.pumpWidget(_app(AnalysisStatusCard(
      session: _session(),
      job: _job(
        AnalysisJobStatus.failed,
        error: 'no calibration on the server',
      ),
    )));

    expect(find.textContaining('no calibration on the server'),
        findsOneWidget);
  });

  testWidgets('done card opens the report view with markdown and court map',
      (tester) async {
    // Sync IO only: awaiting real async IO inside the fake-async test zone
    // hangs the test.
    final dir = Directory.systemTemp.createTempSync('report_ui');
    final report = File('${dir.path}/coach-report.md')
      ..writeAsStringSync('# Coach Report\nSharper lunges next block.');
    final courtMap = File('${dir.path}/court-map.png')
      ..writeAsBytesSync(_pngBytes);

    await tester.pumpWidget(_app(AnalysisStatusCard(
      session: _session(
        reportPath: report.path,
        courtMapPath: courtMap.path,
      ),
      job: null,
    )));

    await tester.tap(find.textContaining('Coach report'));
    // Image.file does real-async IO + decode that the fake-async test zone
    // cannot advance: give it a real-async window, then draw.
    await tester.pump();
    await tester.runAsync(
        () => Future<void>.delayed(const Duration(milliseconds: 300)));
    await tester.pump(const Duration(seconds: 1));

    await tester.pump(const Duration(seconds: 1));

    expect(find.byType(AnalysisReportScreen), findsOneWidget);
    expect(find.textContaining('Sharper lunges next block.'),
        findsOneWidget);
    expect(find.byType(Image, skipOffstage: false), findsOneWidget);

    dir.deleteSync(recursive: true);
  });

  test('markdown export includes the coach report section when present', () {
    final markdown = ExportService.sessionToMarkdown(
      _session(),
      analysisReport: '# Coach Report\nSharper lunges next block.',
    );

    expect(markdown, contains('### BadmintonTrack Coach Report'));
    expect(markdown, contains('Sharper lunges next block.'));

    final without = ExportService.sessionToMarkdown(_session());
    expect(without, isNot(contains('BadmintonTrack')));
  });
}
