import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

import '../models/analysis_job.dart';
import '../models/session.dart';
import '../models/upload_task.dart';
import '../services/analysis_server_settings.dart';
import '../services/database_service.dart';

/// Fire-and-forget analysis tracking (mobile-only): on every tick, sessions
/// with a finished upload but no attached report are polled against the LAN
/// server's jobs API. `done` downloads the coach report + court map into the
/// app documents dir and writes their paths onto the session row; `failed`
/// keeps the server's actionable message for the status card. Both are
/// terminal — the session leaves the polling set.
class AnalysisStatusProvider extends ChangeNotifier {
  final http.Client _http;
  final Future<Directory> Function() _docsDirProvider;
  StreamSubscription<void>? _tickerSub;

  final Map<String, AnalysisJob> _latest = {};
  final Set<String> _settledSessions = {};
  bool _polling = false;

  AnalysisStatusProvider({
    http.Client? httpClient,
    Stream<void>? ticker,
    Future<Directory> Function()? docsDirProvider,
  })  : _http = httpClient ?? http.Client(),
        _docsDirProvider = docsDirProvider ?? getApplicationDocumentsDirectory {
    final effectiveTicker =
        ticker ?? Stream<void>.periodic(const Duration(seconds: 30));
    _tickerSub = effectiveTicker.listen((_) => poll());
  }

  /// Latest known job for a session (drives the status card).
  AnalysisJob? jobFor(String sessionId) => _latest[sessionId];

  @override
  void dispose() {
    _tickerSub?.cancel();
    super.dispose();
  }

  Future<void> poll() async {
    if (_polling) return; // a slow pass must not stack on the next tick
    _polling = true;
    try {
      await _pollOnce();
    } catch (_) {
      // Network blips are routine on a LAN poller; next tick retries.
    } finally {
      _polling = false;
    }
  }

  Future<void> _pollOnce() async {
    final settings = await AnalysisServerSettings.load();
    if (settings.address == null || settings.token == null) return;

    final uploads = await DatabaseService.getUploadTasks();
    final doneSessionIds = uploads
        .where((t) => t.status == UploadStatus.done)
        .map((t) => t.sessionId)
        .toSet()
      ..removeAll(_settledSessions);
    if (doneSessionIds.isEmpty) return;

    final sessions = await DatabaseService.getSessions();
    final bySessionId = {for (final s in sessions) s.id: s};

    for (final sessionId in doneSessionIds) {
      final session = bySessionId[sessionId];
      if (session == null) continue;
      if (session.analysisReportPath != null) {
        _settledSessions.add(sessionId);
        continue;
      }
      final job = await _fetchLatestJob(settings, sessionId);
      if (job == null) continue;
      _latest[sessionId] = job;
      notifyListeners();

      if (job.status == AnalysisJobStatus.done) {
        await _attachArtifacts(settings, job, session);
        _settledSessions.add(sessionId);
        notifyListeners();
      } else if (job.status == AnalysisJobStatus.failed) {
        _settledSessions.add(sessionId);
      }
    }
  }

  Map<String, String> _auth(AnalysisServerConnection settings) =>
      {'authorization': 'Bearer ${settings.token}'};

  Future<AnalysisJob?> _fetchLatestJob(
    AnalysisServerConnection settings,
    String sessionId,
  ) async {
    final response = await _http.get(
      Uri.parse('${settings.address}/api/v1/jobs?sessionId=$sessionId'),
      headers: _auth(settings),
    );
    if (response.statusCode != 200) return null;
    final jobs = (jsonDecode(response.body) as List)
        .map((m) => AnalysisJob.fromJson(Map<String, dynamic>.from(m as Map)))
        .toList();
    return jobs.isEmpty ? null : jobs.first; // newest first per the API
  }

  Future<void> _attachArtifacts(
    AnalysisServerConnection settings,
    AnalysisJob job,
    TrainingSession session,
  ) async {
    final base = await _docsDirProvider();
    final dir = Directory(p.join(base.path, 'analysis', job.sessionId));
    await dir.create(recursive: true);

    final jobUrl = '${settings.address}/api/v1/jobs/${job.id}';
    final report = await _http.get(
      Uri.parse('$jobUrl/report'),
      headers: _auth(settings),
    );
    if (report.statusCode != 200) return; // retry next tick

    final reportPath = p.join(dir.path, 'coach-report.md');
    await File(reportPath).writeAsBytes(report.bodyBytes);

    String? courtMapPath;
    final courtMap = await _http.get(
      Uri.parse('$jobUrl/court-map'),
      headers: _auth(settings),
    );
    if (courtMap.statusCode == 200) {
      courtMapPath = p.join(dir.path, 'court-map.png');
      await File(courtMapPath).writeAsBytes(courtMap.bodyBytes);
    }

    await DatabaseService.updateSession(session.copyWith(
      analysisReportPath: reportPath,
      analysisCourtMapPath: courtMapPath,
    ));
  }
}
