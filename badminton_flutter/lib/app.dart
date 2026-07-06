import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'theme/app_theme.dart';
import 'providers/auth_provider.dart';
import 'providers/session_provider.dart';
import 'providers/tournament_provider.dart';
import 'providers/profile_provider.dart';
import 'providers/player_provider.dart';
import 'screens/auth/login_screen.dart';
import 'screens/player/player_select_screen.dart';
import 'screens/home/home_screen.dart';
import 'screens/train/session_history_screen.dart';
import 'screens/learn/technique_list_screen.dart';
import 'screens/profile/profile_screen.dart';

class BadmintonApp extends StatelessWidget {
  const BadmintonApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Badminton Trainer',
      theme: AppTheme.theme,
      debugShowCheckedModeBanner: false,
      home: const AuthGate(),
    );
  }
}

/// Web requires a login (data lives on the home server); mobile stays
/// offline-first and skips auth entirely.
class AuthGate extends StatelessWidget {
  /// Overrides kIsWeb in tests; production leaves it null.
  final bool? webOverride;

  const AuthGate({super.key, this.webOverride});

  @override
  Widget build(BuildContext context) {
    final isWeb = webOverride ?? kIsWeb;
    if (!isWeb) return const MainShell();
    final auth = context.watch<AuthProvider>();
    if (!auth.isLoggedIn) return const LoginScreen();
    return const WebHome();
  }
}

/// Post-login web routing: pick a player, then enter the main shell.
class WebHome extends StatefulWidget {
  const WebHome({super.key});

  @override
  State<WebHome> createState() => _WebHomeState();
}

class _WebHomeState extends State<WebHome> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final players = context.read<PlayerProvider>();
      if (players.players.isEmpty) players.loadPlayers();
    });
  }

  @override
  Widget build(BuildContext context) {
    final players = context.watch<PlayerProvider>();
    if (players.activePlayer == null) return const PlayerSelectScreen();
    return const MainShell();
  }
}

class MainShell extends StatefulWidget {
  const MainShell({super.key});

  @override
  State<MainShell> createState() => _MainShellState();
}

class _MainShellState extends State<MainShell> {
  int _currentIndex = 0;

  static const _tabs = [
    HomeScreen(),
    SessionHistoryScreen(),
    TechniqueListScreen(),
    ProfileScreen(),
  ];

  @override
  void initState() {
    super.initState();
    // Load data on app start
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<SessionProvider>().loadSessions();
      context.read<TournamentProvider>().loadTournaments();
      context.read<ProfileProvider>().loadProfile();
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: IndexedStack(
        index: _currentIndex,
        children: _tabs,
      ),
      bottomNavigationBar: BottomNavigationBar(
        currentIndex: _currentIndex,
        onTap: (index) => setState(() => _currentIndex = index),
        items: const [
          BottomNavigationBarItem(
            icon: Icon(Icons.home_outlined),
            activeIcon: Icon(Icons.home),
            label: 'Home',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.fitness_center_outlined),
            activeIcon: Icon(Icons.fitness_center),
            label: 'Train',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.menu_book_outlined),
            activeIcon: Icon(Icons.menu_book),
            label: 'Learn',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.person_outline),
            activeIcon: Icon(Icons.person),
            label: 'Profile',
          ),
        ],
      ),
    );
  }
}
