import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'app.dart';
import 'providers/session_provider.dart';
import 'providers/tournament_provider.dart';
import 'providers/profile_provider.dart';
import 'services/database_service.dart';
import 'data/sample_sessions_seed.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Seed sample sessions if the database is empty
  final hasData = await DatabaseService.hasAnySessions();
  if (!hasData) {
    final samples = buildSampleSessions();
    await DatabaseService.insertSessions(samples);
  }

  runApp(
    MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) => SessionProvider()),
        ChangeNotifierProvider(create: (_) => TournamentProvider()),
        ChangeNotifierProvider(create: (_) => ProfileProvider()),
      ],
      child: const BadmintonApp(),
    ),
  );
}
