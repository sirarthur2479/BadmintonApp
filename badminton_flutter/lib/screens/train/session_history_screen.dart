import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../providers/session_provider.dart';
import '../../theme/app_theme.dart';
import '../../widgets/session_card.dart';
import '../export_screen.dart';
import 'log_session_screen.dart';

class SessionHistoryScreen extends StatelessWidget {
  const SessionHistoryScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Training History'),
        actions: const [SessionExportAction()],
      ),
      body: const SessionHistoryBody(),
      floatingActionButton: FloatingActionButton(
        onPressed: () => Navigator.push(
          context,
          MaterialPageRoute(builder: (_) => const LogSessionScreen()),
        ),
        child: const Icon(Icons.add),
      ),
    );
  }
}

/// The Sessions tab's app-bar export button (shared by the legacy
/// standalone screen and TrainScreen).
class SessionExportAction extends StatelessWidget {
  const SessionExportAction({super.key});

  @override
  Widget build(BuildContext context) {
    return IconButton(
      icon: const Icon(Icons.ios_share),
      tooltip: 'Export as Markdown',
      onPressed: () => Navigator.push(
        context,
        MaterialPageRoute(builder: (_) => const ExportScreen()),
      ),
    );
  }
}

/// The session list itself, scaffold-free so TrainScreen can host it as a
/// tab body.
class SessionHistoryBody extends StatelessWidget {
  const SessionHistoryBody({super.key});

  @override
  Widget build(BuildContext context) {
    return Consumer<SessionProvider>(
        builder: (context, provider, _) {
          final sessions = provider.sessions;
          if (sessions.isEmpty) {
            return const Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    Icons.fitness_center,
                    size: 56,
                    color: AppTheme.textSecondary,
                  ),
                  SizedBox(height: 12),
                  Text(
                    'No sessions yet.\nStart logging your training!',
                    textAlign: TextAlign.center,
                    style: TextStyle(color: AppTheme.textSecondary),
                  ),
                ],
              ),
            );
          }
          return ListView.builder(
            padding: const EdgeInsets.symmetric(vertical: 8),
            itemCount: sessions.length,
            itemBuilder: (context, index) {
              final session = sessions[index];
              return Dismissible(
                key: Key(session.id),
                direction: DismissDirection.endToStart,
                background: Container(
                  alignment: Alignment.centerRight,
                  padding: const EdgeInsets.only(right: 20),
                  color: Colors.red.shade400,
                  child: const Icon(Icons.delete, color: Colors.white),
                ),
                confirmDismiss: (_) async {
                  return await showDialog<bool>(
                    context: context,
                    builder: (ctx) => AlertDialog(
                      title: const Text('Delete session?'),
                      content: const Text('This cannot be undone.'),
                      actions: [
                        TextButton(
                          onPressed: () => Navigator.pop(ctx, false),
                          child: const Text('Cancel'),
                        ),
                        TextButton(
                          onPressed: () => Navigator.pop(ctx, true),
                          child: const Text(
                            'Delete',
                            style: TextStyle(color: Colors.red),
                          ),
                        ),
                      ],
                    ),
                  );
                },
                onDismissed: (_) => provider.deleteSession(session.id),
                child: SessionCard(
                  session: session,
                  onEdit: () => Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => LogSessionScreen(session: session),
                    ),
                  ),
                  onDelete: () async {
                    final confirm = await showDialog<bool>(
                      context: context,
                      builder: (ctx) => AlertDialog(
                        title: const Text('Delete session?'),
                        content: const Text('This cannot be undone.'),
                        actions: [
                          TextButton(
                            onPressed: () => Navigator.pop(ctx, false),
                            child: const Text('Cancel'),
                          ),
                          TextButton(
                            onPressed: () => Navigator.pop(ctx, true),
                            child: const Text(
                              'Delete',
                              style: TextStyle(color: Colors.red),
                            ),
                          ),
                        ],
                      ),
                    );
                    if (confirm == true) {
                      provider.deleteSession(session.id);
                    }
                  },
                ),
              );
            },
          );
      },
    );
  }
}
