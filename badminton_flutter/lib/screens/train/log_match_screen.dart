import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import 'package:uuid/uuid.dart';

import '../../models/match_log.dart';
import '../../providers/match_log_provider.dart';
import '../../theme/app_theme.dart';
import '../../widgets/star_rating.dart';
import 'tag_points_screen.dart';

class LogMatchScreen extends StatefulWidget {
  /// When non-null the screen edits this log instead of creating one.
  final MatchLog? existing;

  /// Test seam; point tagging is mobile-only, like the upload features.
  final bool? webOverride;

  const LogMatchScreen({super.key, this.existing, this.webOverride});

  @override
  State<LogMatchScreen> createState() => _LogMatchScreenState();
}

class _LogMatchScreenState extends State<LogMatchScreen> {
  DateTime _date = DateTime.now();
  final _opponentController = TextEditingController();
  final _eventContextController = TextEditingController();
  final _scoresController = TextEditingController();
  final _gameplanController = TextEditingController();
  final _performanceNotesController = TextEditingController();
  final _keyMomentsController = TextEditingController();
  final _videoRefController = TextEditingController();
  bool _isWin = true;
  int _readinessScore = 3;
  bool _saving = false;

  bool get _isEditing => widget.existing != null;

  @override
  void initState() {
    super.initState();
    final log = widget.existing;
    if (log != null) {
      _date = log.date;
      _opponentController.text = log.opponent;
      _eventContextController.text = log.eventContext;
      _scoresController.text = log.scores;
      _gameplanController.text = log.gameplan;
      _performanceNotesController.text = log.performanceNotes;
      _keyMomentsController.text = log.keyMoments;
      _videoRefController.text = log.videoRef ?? '';
      _isWin = log.isWin;
      _readinessScore = log.readinessScore;
    }
  }

  @override
  void dispose() {
    _opponentController.dispose();
    _eventContextController.dispose();
    _scoresController.dispose();
    _gameplanController.dispose();
    _performanceNotesController.dispose();
    _keyMomentsController.dispose();
    _videoRefController.dispose();
    super.dispose();
  }

  Future<void> _pickDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _date,
      firstDate: DateTime(2020),
      lastDate: DateTime.now().add(const Duration(days: 1)),
    );
    if (picked != null) setState(() => _date = picked);
  }

  Future<void> _save() async {
    if (_opponentController.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Enter the opponent\'s name first.')),
      );
      return;
    }
    setState(() => _saving = true);
    final provider = context.read<MatchLogProvider>();
    final videoRef = _videoRefController.text.trim();
    final log = MatchLog(
      id: widget.existing?.id ?? const Uuid().v4(),
      date: _date,
      opponent: _opponentController.text.trim(),
      eventContext: _eventContextController.text.trim(),
      scores: _scoresController.text.trim(),
      isWin: _isWin,
      gameplan: _gameplanController.text.trim(),
      readinessScore: _readinessScore,
      performanceNotes: _performanceNotesController.text.trim(),
      keyMoments: _keyMomentsController.text.trim(),
      videoRef: videoRef.isEmpty ? null : videoRef,
    );
    if (_isEditing) {
      await provider.updateMatchLog(log);
    } else {
      await provider.addMatchLog(log);
    }
    if (mounted) Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(_isEditing ? 'Edit Match' : 'Log Match'),
        actions: [
          if (widget.existing?.videoRef != null &&
              !(widget.webOverride ?? kIsWeb))
            IconButton(
              tooltip: 'Tag points',
              icon: const Icon(Icons.sports_score),
              onPressed: () => Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => TagPointsScreen(log: widget.existing!),
                ),
              ),
            ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          const _SectionLabel('Match'),
          ListTile(
            contentPadding: EdgeInsets.zero,
            leading: const Icon(Icons.calendar_today_outlined),
            title: Text(DateFormat('EEE, d MMM yyyy').format(_date)),
            onTap: _pickDate,
          ),
          TextField(
            key: const ValueKey('opponentField'),
            controller: _opponentController,
            decoration: const InputDecoration(labelText: 'Opponent *'),
          ),
          const SizedBox(height: 12),
          TextField(
            key: const ValueKey('eventContextField'),
            controller: _eventContextController,
            decoration: const InputDecoration(
              labelText: 'Event',
              hintText: 'Practice, league, tournament round…',
            ),
          ),
          const SizedBox(height: 12),
          TextField(
            key: const ValueKey('scoresField'),
            controller: _scoresController,
            decoration: const InputDecoration(
              labelText: 'Scores',
              hintText: '21-15, 18-21, 21-19',
            ),
          ),
          const SizedBox(height: 12),
          SegmentedButton<bool>(
            segments: const [
              ButtonSegment(value: true, label: Text('Win')),
              ButtonSegment(value: false, label: Text('Loss')),
            ],
            selected: {_isWin},
            onSelectionChanged: (selection) =>
                setState(() => _isWin = selection.single),
          ),
          const SizedBox(height: 20),
          const _SectionLabel('Before the match'),
          TextField(
            key: const ValueKey('gameplanField'),
            controller: _gameplanController,
            maxLines: 3,
            decoration: const InputDecoration(
              labelText: 'Gameplan',
              hintText: 'What was the plan going in?',
            ),
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              const Text('Readiness'),
              const SizedBox(width: 12),
              StarRating(
                key: const ValueKey('readinessStars'),
                value: _readinessScore,
                onChanged: (v) => setState(() => _readinessScore = v),
                size: 24,
              ),
            ],
          ),
          const SizedBox(height: 20),
          const _SectionLabel('After the match'),
          TextField(
            key: const ValueKey('performanceNotesField'),
            controller: _performanceNotesController,
            maxLines: 4,
            decoration: const InputDecoration(
              labelText: 'Performance notes',
              hintText: 'What worked? What broke down?',
            ),
          ),
          const SizedBox(height: 12),
          TextField(
            key: const ValueKey('keyMomentsField'),
            controller: _keyMomentsController,
            maxLines: 3,
            decoration: const InputDecoration(labelText: 'Key moments'),
          ),
          const SizedBox(height: 12),
          TextField(
            key: const ValueKey('videoRefField'),
            controller: _videoRefController,
            decoration: const InputDecoration(
              labelText: 'Video link or file',
              hintText: 'Optional',
            ),
          ),
          const SizedBox(height: 24),
          FilledButton(
            key: const ValueKey('saveMatchButton'),
            onPressed: _saving ? null : _save,
            child: Text(_isEditing ? 'Update Match' : 'Save Match'),
          ),
          const SizedBox(height: 24),
        ],
      ),
    );
  }
}

class _SectionLabel extends StatelessWidget {
  final String text;

  const _SectionLabel(this.text);

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Text(
        text,
        style: Theme.of(context).textTheme.titleSmall?.copyWith(
          color: AppTheme.textSecondary,
          fontWeight: FontWeight.bold,
        ),
      ),
    );
  }
}
