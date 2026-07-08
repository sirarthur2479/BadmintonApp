import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'app.dart';
import 'providers/analysis_server_provider.dart';
import 'providers/auth_provider.dart';
import 'providers/player_provider.dart';
import 'providers/session_provider.dart';
import 'providers/tournament_provider.dart';
import 'providers/profile_provider.dart';
import 'providers/upload_queue_provider.dart';
import 'services/api_client.dart';
import 'services/tusc_uploader.dart';
import 'services/api_service.dart';
import 'services/database_service.dart';
import 'data/sample_sessions_seed.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  final auth = AuthProvider();
  final apiClient = ApiClient(tokenProvider: () => auth.token);
  final players = PlayerProvider(client: apiClient);
  final analysisServer = AnalysisServerProvider();
  final uploadQueue = UploadQueueProvider(uploaderFactory: TuscUploader.new);
  if (kIsWeb) {
    // Web is server-backed: restore any persisted login, point the data
    // layer at the API (scoped to the active player), never demo-seed.
    await auth.restore();
    DatabaseService.webApi = ApiService(
      client: apiClient,
      activePlayerId: () => players.activePlayer!.id,
    );
  } else {
    await seedSampleDataIfNeeded(await SharedPreferences.getInstance());
    // Mobile-only: the LAN analysis-server connection (video uploads) and
    // any uploads interrupted by the last app kill.
    await analysisServer.restore();
    await uploadQueue.resumePending();
  }

  runApp(
    MultiProvider(
      providers: [
        ChangeNotifierProvider.value(value: auth),
        ChangeNotifierProvider.value(value: players),
        ChangeNotifierProvider(create: (_) => SessionProvider()),
        ChangeNotifierProvider(create: (_) => TournamentProvider()),
        ChangeNotifierProvider(create: (_) => ProfileProvider()),
        ChangeNotifierProvider.value(value: analysisServer),
        ChangeNotifierProvider.value(value: uploadQueue),
      ],
      child: const BadmintonApp(),
    ),
  );
}
