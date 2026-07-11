import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

import 'package:badminton_flutter/models/analysis_job.dart';
import 'package:badminton_flutter/models/session.dart';
import 'package:badminton_flutter/models/upload_task.dart';
import 'package:badminton_flutter/providers/analysis_status_provider.dart';
import 'package:badminton_flutter/services/database_service.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late StreamController<void> ticker;
  late Directory docsDir;

  setUpAll(() {
    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfi;
  });

  setUp(() async {
    ticker = StreamController<void>();
    docsDir = await Directory.systemTemp.createTemp('analysis_test');
    SharedPreferences.setMockInitialValues({
      'analysis_server_address': 'http://192.168.1.50:8001',
      'analysis_token': 'jwt-lan',
      'analysis_player_id': 'pl-1',
      'analysis_player_name': 'Kid One',
    });
    DatabaseService.dbName = 'analysis_status_test.db';
    await DatabaseService.resetForTests();
  });

  tearDown(() async {
    await Future<void>.delayed(const Duration(milliseconds: 100));
    await docsDir.delete(recursive: true);
  });

  Future<void> seedSessionWithDoneUpload({String sessionId = 'sess-42'}) async {
    await DatabaseService.insertSession(TrainingSession(
      id: sessionId,
      date: DateTime(2026, 7, 8),
      durationMinutes: 60,
      drills: const ['Smash'],
    ));
    await DatabaseService.insertUploadTask(UploadTask(
      id: 'ut-$sessionId',
      sessionId: sessionId,
      playerId: 'pl-1',
      mode: 'footwork',
      filePath: '/videos/clip.mp4',
      totalBytes: 100,
      sentBytes: 100,
      status: UploadStatus.done,
    ));
  }

  AnalysisStatusProvider makeProvider(MockClientHandler handler) =>
      AnalysisStatusProvider(
        httpClient: MockClient(handler),
        ticker: ticker.stream,
        docsDirProvider: () async => docsDir,
      );

  Future<void> tickAndSettle() async {
    ticker.add(null);
    await Future<void>.delayed(const Duration(milliseconds: 100));
  }

  Map<String, dynamic> jobJson(String status, {String? error}) => {
        'id': 'job-1',
        'playerId': 'pl-1',
        'sessionId': 'sess-42',
        'mode': 'footwork',
        'status': status,
        'errorMessage': error,
        'createdAt': 'now',
        'startedAt': null,
        'finishedAt': null,
      };

  test('polls until done then attaches report and court map paths', () async {
    var jobStatus = 'analyzing';
    var listCalls = 0;
    final provider = makeProvider((request) async {
      final path = request.url.path;
      if (path == '/api/v1/jobs') {
        listCalls += 1;
        expect(request.url.queryParameters['sessionId'], 'sess-42');
        expect(request.headers['authorization'], 'Bearer jwt-lan');
        return http.Response(jsonEncode([jobJson(jobStatus)]), 200);
      }
      if (path.endsWith('/report')) {
        return http.Response('# Coach Report\ngreat lunges', 200);
      }
      if (path.endsWith('/court-map')) {
        return http.Response.bytes([0x89, 0x50, 0x4E, 0x47], 200);
      }
      return http.Response('{}', 404);
    });
    await seedSessionWithDoneUpload();

    await tickAndSettle();
    expect(provider.jobFor('sess-42')?.status, AnalysisJobStatus.analyzing);
    expect(
      (await DatabaseService.getSessions()).single.analysisReportPath,
      isNull,
    );

    jobStatus = 'done';
    await tickAndSettle();

    final session = (await DatabaseService.getSessions()).single;
    expect(session.analysisReportPath, isNotNull);
    expect(File(session.analysisReportPath!).readAsStringSync(),
        contains('great lunges'));
    expect(session.analysisCourtMapPath, isNotNull);
    expect(File(session.analysisCourtMapPath!).existsSync(), isTrue);

    // Attached -> the session drops out of the polling set.
    final callsAfterDone = listCalls;
    await tickAndSettle();
    expect(listCalls, callsAfterDone);
  });

  test('failed job records the error and stops polling', () async {
    var listCalls = 0;
    final provider = makeProvider((request) async {
      if (request.url.path == '/api/v1/jobs') {
        listCalls += 1;
        return http.Response(
          jsonEncode([
            jobJson('failed', error: 'no calibration on the server')
          ]),
          200,
        );
      }
      return http.Response('{}', 404);
    });
    await seedSessionWithDoneUpload();

    await tickAndSettle();

    expect(provider.jobFor('sess-42')?.status, AnalysisJobStatus.failed);
    expect(provider.jobFor('sess-42')?.errorMessage,
        'no calibration on the server');
    final callsAfterFail = listCalls;
    await tickAndSettle();
    expect(listCalls, callsAfterFail, reason: 'failed is terminal');
    expect(
      (await DatabaseService.getSessions()).single.analysisReportPath,
      isNull,
    );
  });

  test('does not poll sessions without completed uploads', () async {
    var requests = 0;
    makeProvider((request) async {
      requests += 1;
      return http.Response('[]', 200);
    });
    await DatabaseService.insertSession(TrainingSession(
      id: 'sess-fresh',
      date: DateTime(2026, 7, 8),
      durationMinutes: 30,
      drills: const [],
    ));
    await DatabaseService.insertUploadTask(const UploadTask(
      id: 'ut-pending',
      sessionId: 'sess-fresh',
      playerId: 'pl-1',
      mode: 'footwork',
      filePath: '/v.mp4',
      totalBytes: 10,
      status: UploadStatus.pending,
    ));

    await tickAndSettle();

    expect(requests, 0);
  });

  test('dispose cancels the ticker subscription', () async {
    final provider = makeProvider((_) async => http.Response('[]', 200));

    provider.dispose();

    expect(ticker.hasListener, isFalse);
  });
}
