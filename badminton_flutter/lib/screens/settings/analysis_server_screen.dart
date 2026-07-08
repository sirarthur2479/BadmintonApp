import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../models/player.dart';
import '../../providers/analysis_server_provider.dart';

/// Mobile-only: connect the app to the home analysis server (LAN address,
/// account sign-in, which player uploads belong to, connection test).
class AnalysisServerScreen extends StatefulWidget {
  const AnalysisServerScreen({super.key});

  @override
  State<AnalysisServerScreen> createState() => _AnalysisServerScreenState();
}

class _AnalysisServerScreenState extends State<AnalysisServerScreen> {
  final _addressController = TextEditingController();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();

  List<Player> _players = const [];
  String? _error;
  String? _connectionMessage;
  bool _busy = false;

  @override
  void initState() {
    super.initState();
    final provider = context.read<AnalysisServerProvider>();
    _addressController.text = provider.address ?? '';
    if (provider.token != null) _loadPlayers();
  }

  @override
  void dispose() {
    _addressController.dispose();
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  Future<void> _loadPlayers() async {
    try {
      final players =
          await context.read<AnalysisServerProvider>().loadPlayers();
      if (mounted) setState(() => _players = players);
    } catch (e) {
      if (mounted) setState(() => _error = 'Could not load players: $e');
    }
  }

  Future<void> _signIn() async {
    final provider = context.read<AnalysisServerProvider>();
    setState(() {
      _busy = true;
      _error = null;
    });
    await provider.configure(_addressController.text);
    final error = await provider.login(
      _emailController.text.trim(),
      _passwordController.text,
    );
    if (!mounted) return;
    setState(() {
      _busy = false;
      _error = error;
    });
    if (error == null) await _loadPlayers();
  }

  Future<void> _testConnection() async {
    final provider = context.read<AnalysisServerProvider>();
    await provider.configure(_addressController.text);
    final result = await provider.testConnection();
    if (mounted) setState(() => _connectionMessage = result.message);
  }

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<AnalysisServerProvider>();
    final signedIn = provider.token != null;

    return Scaffold(
      appBar: AppBar(title: const Text('Analysis Server')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          const Text(
            'Videos upload to your home server over WiFi only and never '
            'leave your network.',
          ),
          const SizedBox(height: 16),
          TextField(
            key: const ValueKey('addressField'),
            controller: _addressController,
            decoration: const InputDecoration(
              labelText: 'Server address (LAN)',
              hintText: '192.168.1.50:8001',
            ),
            keyboardType: TextInputType.url,
          ),
          const SizedBox(height: 16),
          if (!signedIn) ...[
            TextField(
              key: const ValueKey('emailField'),
              controller: _emailController,
              decoration: const InputDecoration(labelText: 'Email'),
              keyboardType: TextInputType.emailAddress,
            ),
            TextField(
              key: const ValueKey('passwordField'),
              controller: _passwordController,
              decoration: const InputDecoration(labelText: 'Password'),
              obscureText: true,
            ),
            const SizedBox(height: 12),
            ElevatedButton(
              key: const ValueKey('signInButton'),
              onPressed: _busy ? null : _signIn,
              child: const Text('Sign in'),
            ),
          ] else ...[
            Row(
              children: [
                const Icon(Icons.check_circle, color: Colors.green),
                const SizedBox(width: 8),
                const Expanded(child: Text('Signed in')),
                TextButton(
                  key: const ValueKey('signOutButton'),
                  onPressed: () async {
                    await provider.signOut();
                    if (mounted) setState(() => _players = const []);
                  },
                  child: const Text('Sign out'),
                ),
              ],
            ),
            const SizedBox(height: 8),
            const Text('Uploads belong to:'),
            for (final player in _players)
              ListTile(
                title: Text(player.name),
                leading: Icon(
                  provider.playerId == player.id
                      ? Icons.radio_button_checked
                      : Icons.radio_button_off,
                ),
                onTap: () => provider.selectPlayer(player.id, player.name),
              ),
          ],
          if (_error != null)
            Padding(
              padding: const EdgeInsets.only(top: 12),
              child: Text(
                _error!,
                style: TextStyle(color: Theme.of(context).colorScheme.error),
              ),
            ),
          const Divider(height: 32),
          OutlinedButton(
            key: const ValueKey('testConnectionButton'),
            onPressed: _testConnection,
            child: const Text('Test connection'),
          ),
          if (_connectionMessage != null)
            Padding(
              padding: const EdgeInsets.only(top: 12),
              child: Text(_connectionMessage!),
            ),
        ],
      ),
    );
  }
}
