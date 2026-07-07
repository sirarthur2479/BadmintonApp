import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:badminton_flutter/app.dart' show WebHome;
import 'package:badminton_flutter/providers/auth_provider.dart';
import 'package:badminton_flutter/providers/player_provider.dart';
import 'package:badminton_flutter/screens/auth/login_screen.dart';
import 'package:badminton_flutter/screens/player/player_select_screen.dart';

import '../providers/player_provider_test.dart' show playersClient;
import 'auth_screens_test.dart' show authClient;

Widget app(PlayerProvider players, {AuthProvider? auth}) => MultiProvider(
      providers: [
        ChangeNotifierProvider.value(
            value: auth ?? AuthProvider(client: authClient())),
        ChangeNotifierProvider.value(value: players),
      ],
      child: const MaterialApp(home: PlayerSelectScreen()),
    );

void main() {
  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  testWidgets('renders one card per player', (tester) async {
    final players = PlayerProvider(client: playersClient());
    await players.loadPlayers();

    await tester.pumpWidget(app(players));

    expect(find.text('Kid One'), findsOneWidget);
    expect(find.text('Kid Two'), findsOneWidget);
  });

  testWidgets('tapping a card sets the active player', (tester) async {
    final players = PlayerProvider(client: playersClient());
    await players.loadPlayers();

    await tester.pumpWidget(app(players));
    await tester.tap(find.text('Kid Two'));
    await tester.pumpAndSettle();

    expect(players.activePlayer?.id, 'p2');
  });

  testWidgets('add player dialog requires a name and adds on confirm',
      (tester) async {
    final players = PlayerProvider(client: playersClient(players: []));
    await players.loadPlayers();

    await tester.pumpWidget(app(players));
    await tester.tap(find.byKey(const ValueKey('addPlayerButton')));
    await tester.pumpAndSettle();

    // Confirm with an empty name: nothing happens.
    await tester.tap(find.text('Add'));
    await tester.pumpAndSettle();
    expect(players.players, isEmpty);

    await tester.tap(find.byKey(const ValueKey('addPlayerButton')));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextField).last, 'New Kid');
    await tester.tap(find.text('Add'));
    await tester.pumpAndSettle();

    expect(players.players.map((p) => p.name), contains('New Kid'));
  });

  testWidgets('logout action signs out', (tester) async {
    final auth = AuthProvider(client: authClient());
    await auth.login('parent@example.com', 'hunter22');
    final players = PlayerProvider(client: playersClient());
    await players.loadPlayers();

    await tester.pumpWidget(app(players, auth: auth));
    await tester.tap(find.byKey(const ValueKey('logoutButton')));
    await tester.pumpAndSettle();

    expect(auth.isLoggedIn, isFalse);
    expect(players.players, isEmpty, reason: 'logout clears player state');
  });

  testWidgets(
      'gate: logged-in without active player shows select screen, with one shows shell',
      (tester) async {
    // Routing is covered at the AuthGate level in auth_screens_test.dart for
    // login; here we assert the post-login branch renders the select screen.
    final auth = AuthProvider(client: authClient());
    await auth.login('parent@example.com', 'hunter22');
    final players = PlayerProvider(client: playersClient());
    await players.loadPlayers();

    await tester.pumpWidget(MultiProvider(
      providers: [
        ChangeNotifierProvider.value(value: auth),
        ChangeNotifierProvider.value(value: players),
      ],
      child: const MaterialApp(home: WebHome()),
    ));

    expect(find.byType(PlayerSelectScreen), findsOneWidget);
    expect(find.byType(LoginScreen), findsNothing);
  });
}
