import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:uuid/uuid.dart';
import 'package:intl/intl.dart';
import '../../models/tournament.dart';
import '../../providers/tournament_provider.dart';
import '../../theme/app_theme.dart';
import '../../widgets/confirm_delete.dart';

class TournamentScreen extends StatelessWidget {
  const TournamentScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Tournaments')),
      body: Consumer<TournamentProvider>(
        builder: (context, provider, _) {
          final tournaments = provider.tournaments;
          final totalMatches = provider.totalMatches;

          return Column(
            children: [
              // Win/loss summary
              if (totalMatches > 0)
                Padding(
                  padding: const EdgeInsets.all(16),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      _WinLossBadge(
                          label: 'Wins',
                          count: provider.totalWins,
                          color: AppTheme.primary),
                      const SizedBox(width: 12),
                      _WinLossBadge(
                          label: 'Losses',
                          count: provider.totalLosses,
                          color: Colors.red.shade400),
                      const SizedBox(width: 12),
                      _WinLossBadge(
                        label: 'Win rate',
                        count: (provider.winRate * 100).round(),
                        suffix: '%',
                        color: AppTheme.primaryLight,
                      ),
                    ],
                  ),
                ),

              // Tournament list
              Expanded(
                child: tournaments.isEmpty
                    ? const Center(
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(Icons.emoji_events_outlined,
                                size: 56, color: AppTheme.textSecondary),
                            SizedBox(height: 12),
                            Text(
                              'No tournaments yet.\nTap + to add one!',
                              textAlign: TextAlign.center,
                              style:
                                  TextStyle(color: AppTheme.textSecondary),
                            ),
                          ],
                        ),
                      )
                    : ListView.builder(
                        padding: const EdgeInsets.symmetric(vertical: 8),
                        itemCount: tournaments.length,
                        itemBuilder: (context, index) {
                          return _TournamentTile(
                              tournament: tournaments[index]);
                        },
                      ),
              ),
            ],
          );
        },
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () => _showAddTournamentDialog(context),
        child: const Icon(Icons.add),
      ),
    );
  }

  void _showAddTournamentDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (_) => const _AddTournamentDialog(),
    );
  }
}

class _TournamentTile extends StatefulWidget {
  final Tournament tournament;

  const _TournamentTile({required this.tournament});

  @override
  State<_TournamentTile> createState() => _TournamentTileState();
}

class _TournamentTileState extends State<_TournamentTile> {
  bool _expanded = false;

  @override
  Widget build(BuildContext context) {
    final t = widget.tournament;
    return Card(
      child: Column(
        children: [
          ListTile(
            leading: const Icon(Icons.emoji_events, color: AppTheme.primary),
            title: Text(t.name,
                style: const TextStyle(fontWeight: FontWeight.w600)),
            subtitle: Text(
              '${DateFormat('d MMM yyyy').format(t.date)} · ${t.location}',
              style: const TextStyle(fontSize: 12),
            ),
            trailing: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                _MiniStat('W', t.wins, AppTheme.primary),
                const SizedBox(width: 6),
                _MiniStat('L', t.losses, Colors.red.shade400),
                const SizedBox(width: 4),
                Icon(
                  _expanded ? Icons.expand_less : Icons.expand_more,
                  color: AppTheme.textSecondary,
                ),
              ],
            ),
            onTap: () => setState(() => _expanded = !_expanded),
          ),
          if (_expanded) ...[
            const Divider(height: 1),
            ...t.matches.map((m) => _MatchRow(
                match: m, tournamentId: t.id)),
            Padding(
              padding: const EdgeInsets.all(8),
              child: Row(
                children: [
                  TextButton.icon(
                    onPressed: () =>
                        _showAddMatchDialog(context, t.id),
                    icon: const Icon(Icons.add, size: 16),
                    label: const Text('Add match'),
                    style: TextButton.styleFrom(
                        foregroundColor: AppTheme.primary),
                  ),
                  const Spacer(),
                  TextButton.icon(
                    onPressed: () async {
                      final provider =
                          context.read<TournamentProvider>();
                      if (await confirmDelete(context,
                          title: 'Delete tournament?',
                          message:
                              'All its matches will be deleted too.')) {
                        await provider.deleteTournament(t.id);
                      }
                    },
                    icon: const Icon(Icons.delete_outline, size: 16),
                    label: const Text('Delete tournament'),
                    style: TextButton.styleFrom(
                        foregroundColor: Colors.red.shade400),
                  ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }

  void _showAddMatchDialog(BuildContext context, String tournamentId) {
    showDialog(
      context: context,
      builder: (_) => _AddMatchDialog(tournamentId: tournamentId),
    );
  }
}

class _MatchRow extends StatelessWidget {
  final TournamentMatch match;
  final String tournamentId;

  const _MatchRow({required this.match, required this.tournamentId});

  @override
  Widget build(BuildContext context) {
    return ListTile(
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 0),
      leading: Icon(
        match.isWin ? Icons.check_circle : Icons.cancel,
        color: match.isWin ? AppTheme.primary : Colors.red.shade400,
        size: 20,
      ),
      title: Text('vs ${match.opponent}',
          style: const TextStyle(fontSize: 14)),
      subtitle: match.scores.isNotEmpty
          ? Text(match.scores.join(', '),
              style: const TextStyle(fontSize: 12))
          : null,
      trailing: IconButton(
        icon: const Icon(Icons.delete_outline,
            size: 18, color: AppTheme.textSecondary),
        onPressed: () async {
          final provider = context.read<TournamentProvider>();
          if (await confirmDelete(context, title: 'Delete match?')) {
            await provider.deleteMatch(match.id, tournamentId);
          }
        },
      ),
    );
  }
}

// ── Dialogs ──────────────────────────────────────────────────────────────────

class _AddTournamentDialog extends StatefulWidget {
  const _AddTournamentDialog();

  @override
  State<_AddTournamentDialog> createState() => _AddTournamentDialogState();
}

class _AddTournamentDialogState extends State<_AddTournamentDialog> {
  final _nameCtrl = TextEditingController();
  final _locationCtrl = TextEditingController();
  final _formatCtrl = TextEditingController(text: 'Knockout');
  DateTime _date = DateTime.now();

  @override
  void dispose() {
    _nameCtrl.dispose();
    _locationCtrl.dispose();
    _formatCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Add Tournament'),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
                controller: _nameCtrl,
                decoration: const InputDecoration(labelText: 'Tournament name')),
            const SizedBox(height: 12),
            TextField(
                controller: _locationCtrl,
                decoration: const InputDecoration(labelText: 'Location')),
            const SizedBox(height: 12),
            TextField(
                controller: _formatCtrl,
                decoration: const InputDecoration(labelText: 'Format')),
            const SizedBox(height: 12),
            ListTile(
              contentPadding: EdgeInsets.zero,
              title: Text(DateFormat('d MMM yyyy').format(_date)),
              leading: const Icon(Icons.calendar_today),
              onTap: () async {
                final picked = await showDatePicker(
                  context: context,
                  initialDate: _date,
                  firstDate: DateTime(2020),
                  lastDate: DateTime.now().add(const Duration(days: 365)),
                );
                if (picked != null) setState(() => _date = picked);
              },
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel')),
        ElevatedButton(
          onPressed: () {
            if (_nameCtrl.text.trim().isEmpty) return;
            final t = Tournament(
              id: const Uuid().v4(),
              name: _nameCtrl.text.trim(),
              date: _date,
              location: _locationCtrl.text.trim(),
              format: _formatCtrl.text.trim(),
            );
            context.read<TournamentProvider>().addTournament(t);
            Navigator.pop(context);
          },
          child: const Text('Add'),
        ),
      ],
    );
  }
}

class _AddMatchDialog extends StatefulWidget {
  final String tournamentId;

  const _AddMatchDialog({required this.tournamentId});

  @override
  State<_AddMatchDialog> createState() => _AddMatchDialogState();
}

class _AddMatchDialogState extends State<_AddMatchDialog> {
  final _opponentCtrl = TextEditingController();
  final _scoresCtrl = TextEditingController();
  bool _isWin = true;

  @override
  void dispose() {
    _opponentCtrl.dispose();
    _scoresCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Add Match'),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          TextField(
              controller: _opponentCtrl,
              decoration: const InputDecoration(labelText: 'Opponent name')),
          const SizedBox(height: 12),
          TextField(
            controller: _scoresCtrl,
            decoration: const InputDecoration(
              labelText: 'Scores',
              hintText: 'e.g. 21-15, 21-18',
            ),
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              const Text('Result:'),
              const SizedBox(width: 12),
              ChoiceChip(
                label: const Text('Win'),
                selected: _isWin,
                onSelected: (_) => setState(() => _isWin = true),
                selectedColor: AppTheme.primary,
                labelStyle: TextStyle(
                    color: _isWin ? Colors.white : AppTheme.textPrimary),
              ),
              const SizedBox(width: 8),
              ChoiceChip(
                label: const Text('Loss'),
                selected: !_isWin,
                onSelected: (_) => setState(() => _isWin = false),
                selectedColor: Colors.red.shade400,
                labelStyle: TextStyle(
                    color: !_isWin ? Colors.white : AppTheme.textPrimary),
              ),
            ],
          ),
        ],
      ),
      actions: [
        TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel')),
        ElevatedButton(
          onPressed: () {
            if (_opponentCtrl.text.trim().isEmpty) return;
            final scores = _scoresCtrl.text
                .split(',')
                .map((s) => s.trim())
                .where((s) => s.isNotEmpty)
                .toList();
            final match = TournamentMatch(
              id: const Uuid().v4(),
              tournamentId: widget.tournamentId,
              opponent: _opponentCtrl.text.trim(),
              scores: scores,
              isWin: _isWin,
            );
            context.read<TournamentProvider>().addMatch(match);
            Navigator.pop(context);
          },
          child: const Text('Add'),
        ),
      ],
    );
  }
}

// ── Small helper widgets ──────────────────────────────────────────────────────

class _WinLossBadge extends StatelessWidget {
  final String label;
  final int count;
  final Color color;
  final String suffix;

  const _WinLossBadge({
    required this.label,
    required this.count,
    required this.color,
    this.suffix = '',
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        children: [
          Text('$count$suffix',
              style: TextStyle(
                  fontSize: 22, fontWeight: FontWeight.bold, color: color)),
          Text(label,
              style: const TextStyle(
                  fontSize: 11, color: AppTheme.textSecondary)),
        ],
      ),
    );
  }
}

class _MiniStat extends StatelessWidget {
  final String label;
  final int count;
  final Color color;

  const _MiniStat(this.label, this.count, this.color);

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(6),
      ),
      child: Text('$label $count',
          style: TextStyle(
              fontSize: 11, fontWeight: FontWeight.w600, color: color)),
    );
  }
}
