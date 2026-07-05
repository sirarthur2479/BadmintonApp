import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'app.dart';
import 'providers/session_provider.dart';
import 'providers/tournament_provider.dart';
import 'providers/profile_provider.dart';
import 'data/sample_sessions_seed.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  await seedSampleDataIfNeeded(await SharedPreferences.getInstance());

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
