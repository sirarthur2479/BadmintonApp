import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../providers/auth_provider.dart';
import '../../providers/player_provider.dart';
import '../../theme/app_theme.dart';

/// Pick which player this session is about; one login, many players.
class PlayerSelectScreen extends StatelessWidget {
  const PlayerSelectScreen({super.key});

  Future<void> _addPlayer(BuildContext context) async {
    final controller = TextEditingController();
    final provider = context.read<PlayerProvider>();
    final name = await showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Add player'),
        content: TextField(
          controller: controller,
          autofocus: true,
          decoration: const InputDecoration(hintText: 'Player name'),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, controller.text.trim()),
            child: const Text('Add'),
          ),
        ],
      ),
    );
    if (name != null && name.isNotEmpty) {
      await provider.addPlayer(name: name);
    }
    // The controller is NOT disposed here: the dialog route is still
    // animating out and its TextField would touch a disposed controller.
    // The short-lived controller is simply left to the GC.
  }

  @override
  Widget build(BuildContext context) {
    final players = context.watch<PlayerProvider>();
    return Scaffold(
      appBar: AppBar(
        title: const Text('Who is training?'),
        actions: [
          IconButton(
            key: const ValueKey('logoutButton'),
            icon: const Icon(Icons.logout),
            tooltip: 'Sign out',
            onPressed: () async {
              await context.read<PlayerProvider>().clear();
              if (context.mounted) {
                await context.read<AuthProvider>().logout();
              }
            },
          ),
        ],
      ),
      body: GridView.count(
        crossAxisCount: 2,
        padding: const EdgeInsets.all(16),
        crossAxisSpacing: 12,
        mainAxisSpacing: 12,
        children: [
          for (final player in players.players)
            Card(
              child: InkWell(
                onTap: () => players.switchPlayer(player.id),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const CircleAvatar(
                      radius: 28,
                      backgroundColor: AppTheme.primaryLight,
                      child: Icon(Icons.person, color: Colors.white, size: 32),
                    ),
                    const SizedBox(height: 12),
                    Text(
                      player.name,
                      style: Theme.of(context).textTheme.titleMedium,
                    ),
                    if (player.club.isNotEmpty)
                      Text(
                        player.club,
                        style: Theme.of(context).textTheme.bodySmall,
                      ),
                  ],
                ),
              ),
            ),
          Card(
            child: InkWell(
              key: const ValueKey('addPlayerButton'),
              onTap: () => _addPlayer(context),
              child: const Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.add_circle_outline,
                      size: 44, color: AppTheme.primary),
                  SizedBox(height: 12),
                  Text('Add Player'),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
