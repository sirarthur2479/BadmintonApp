import 'package:flutter/foundation.dart'
    show defaultTargetPlatform, kIsWeb, TargetPlatform;
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'app.dart';
import 'providers/analysis_server_provider.dart';
import 'providers/analysis_status_provider.dart';
import 'providers/auth_provider.dart';
import 'providers/match_log_provider.dart';
import 'providers/point_record_provider.dart';
import 'providers/player_provider.dart';
import 'providers/session_provider.dart';
import 'providers/tournament_provider.dart';
import 'providers/profile_provider.dart';
import 'providers/upload_queue_provider.dart';
import 'services/api_client.dart';
import 'services/connectivity_gate.dart';
import 'services/tusc_uploader.dart';
import 'services/api_service.dart';
import 'services/database_service.dart';
import 'data/sample_sessions_seed.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Laptop/desktop builds keep the same offline-first sqflite data layer;
  // Linux/Windows need the ffi factory (macOS/iOS/Android are native).
  if (!kIsWeb &&
      (defaultTargetPlatform == TargetPlatform.linux ||
          defaultTargetPlatform == TargetPlatform.windows)) {
    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfi;
  }

  final auth = AuthProvider();
  final apiClient = ApiClient(tokenProvider: () => auth.token);
  final players = PlayerProvider(client: apiClient);
  final analysisServer = AnalysisServerProvider();
  late final UploadQueueProvider uploadQueue;
  AnalysisStatusProvider? analysisStatus;
  if (kIsWeb) {
    // Web is server-backed: restore any persisted login, point the data
    // layer at the API (scoped to the active player), never demo-seed.
    // No gate: web never uploads video, the queue stays empty.
    uploadQueue = UploadQueueProvider(uploaderFactory: TuscUploader.new);
    await auth.restore();
    DatabaseService.webApi = ApiService(
      client: apiClient,
      activePlayerId: () => players.activePlayer!.id,
    );
  } else {
    await seedSampleDataIfNeeded(await SharedPreferences.getInstance());
    // Mobile-only: the LAN analysis-server connection, the WiFi-only
    // upload gate, and any uploads interrupted by the last app kill.
    final gate = ConnectivityGate();
    await gate.initialise();
    uploadQueue = UploadQueueProvider(
      uploaderFactory: TuscUploader.new,
      gate: gate,
    );
    await analysisServer.restore();
    await uploadQueue.resumePending();
    // Polls the server for analysis results and attaches reports to
    // sessions; its default 30s ticker only does work when uploads exist.
    analysisStatus = AnalysisStatusProvider();
  }

  runApp(
    MultiProvider(
      providers: [
        ChangeNotifierProvider.value(value: auth),
        ChangeNotifierProvider.value(value: players),
        ChangeNotifierProvider(create: (_) => SessionProvider()),
        ChangeNotifierProvider(create: (_) => TournamentProvider()),
        ChangeNotifierProvider(create: (_) => ProfileProvider()),
        ChangeNotifierProvider(create: (_) => MatchLogProvider()),
        ChangeNotifierProvider(create: (_) => PointRecordProvider()),
        ChangeNotifierProvider.value(value: analysisServer),
        ChangeNotifierProvider.value(value: uploadQueue),
        if (analysisStatus != null)
          ChangeNotifierProvider<AnalysisStatusProvider>.value(
            value: analysisStatus,
          ),
      ],
      child: const BadmintonApp(),
    ),
  );
}
