import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:uuid/uuid.dart';
import 'package:video_player/video_player.dart' hide VideoScrubber;

import '../../models/match_log.dart';
import '../../models/point_record.dart';
import '../../providers/point_record_provider.dart';
import '../../services/tagging_video_controller.dart';
import '../../services/video_player_tagging_controller.dart';
import '../../utils/point_derivation.dart';
import '../../widgets/video_scrubber.dart';

/// Phase-1 human-in-the-loop tagging (pool #10): scrub the match video and
/// record one PointRecord per rally with a handful of taps. Server, score,
/// and game are derived (point_derivation.dart); the video timestamp is
/// captured pause-then-read (research/flutter-video.md).
class TagPointsScreen extends StatefulWidget {
  const TagPointsScreen({super.key, required this.log, this.video});

  final MatchLog log;

  /// Injectable video seam; a production controller is created when null.
  final TaggingVideoController? video;

  @override
  State<TagPointsScreen> createState() => _TagPointsScreenState();
}

class _TagPointsScreenState extends State<TagPointsScreen> {
  late final TaggingVideoController _video;
  bool _ownsVideo = false;
  bool _videoReady = false;

  String? _firstServer;
  String? _winner;
  String? _endingType;
  String? _endingShot;
  String? _endingZone;
  String? _endingSide;

  static const _endingTypeLabels = {
    'winner': 'Winner',
    'forcedError': 'Forced error',
    'unforcedError': 'Unforced error',
  };

  @override
  void initState() {
    super.initState();
    if (widget.video != null) {
      _video = widget.video!;
      _videoReady = true;
    } else {
      _video = VideoPlayerTaggingController();
      _ownsVideo = true;
      _video.init(widget.log.videoRef!).then((_) {
        if (mounted) setState(() => _videoReady = true);
      });
    }
  }

  @override
  void dispose() {
    if (_ownsVideo) _video.dispose();
    super.dispose();
  }

  bool get _canSave => _winner != null && _endingType != null;

  Future<void> _savePoint() async {
    final provider = context.read<PointRecordProvider>();
    // Pause first: the paused position is the stable timestamp source.
    await _video.pause();
    final points = provider.points;
    final game = currentGame(points);
    final gamePoints = points.where((p) => p.game == game).toList();
    final score = scoreAfter(gamePoints, _winner!);
    final point = PointRecord(
      id: const Uuid().v4(),
      matchLogId: widget.log.id,
      game: game,
      indexInGame: gamePoints.length + 1,
      server: serverForNext(points, _firstServer ?? 'player'),
      winner: _winner!,
      playerScore: score.player,
      opponentScore: score.opponent,
      endingType: _endingType!,
      endingShot: _endingShot,
      endingZone: _endingZone,
      endingSide: _endingSide,
      videoTimestampMs: _video.position.value.inMilliseconds,
    );
    await provider.addPoint(point);
    if (!mounted) return;
    setState(() {
      _winner = null;
      _endingType = null;
      _endingShot = null;
      _endingZone = null;
      _endingSide = null;
    });
  }

  Widget _videoView() {
    final video = _video;
    if (video is VideoPlayerTaggingController) {
      final inner = video.inner;
      if (_videoReady && inner != null && inner.value.isInitialized) {
        return AspectRatio(
          aspectRatio: inner.value.aspectRatio,
          child: VideoPlayer(inner),
        );
      }
    } else if (_videoReady) {
      // Injected seam (tests): no platform view to show.
      return const SizedBox(height: 8);
    }
    return const AspectRatio(
      aspectRatio: 16 / 9,
      child: ColoredBox(
        color: Colors.black87,
        child: Center(
          child: Icon(Icons.ondemand_video, color: Colors.white54, size: 42),
        ),
      ),
    );
  }

  Widget _header(List<PointRecord> points) {
    final game = currentGame(points);
    final gamePoints = points.where((p) => p.game == game).toList();
    var player = 0;
    var opponent = 0;
    if (gamePoints.isNotEmpty) {
      player = gamePoints.last.playerScore;
      opponent = gamePoints.last.opponentScore;
    }
    return Text(
      'Game $game · $player–$opponent · ${points.length} '
      '${points.length == 1 ? 'point' : 'points'} tagged',
      style: Theme.of(context).textTheme.titleMedium,
    );
  }

  Widget _firstServerPrompt() {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            Text(
              'Who serves first?',
              style: Theme.of(context).textTheme.titleMedium,
            ),
            const SizedBox(height: 12),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                ChoiceChip(
                  key: const ValueKey('serveFirstPlayer'),
                  label: const Text('We serve'),
                  selected: false,
                  onSelected: (_) => setState(() => _firstServer = 'player'),
                ),
                const SizedBox(width: 12),
                ChoiceChip(
                  key: const ValueKey('serveFirstOpponent'),
                  label: const Text('They serve'),
                  selected: false,
                  onSelected: (_) => setState(() => _firstServer = 'opponent'),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _winnerButtons() {
    Widget button(String side, String label, Key key) {
      final selected = _winner == side;
      return Expanded(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 4),
          child: FilledButton.tonal(
            key: key,
            style: selected
                ? FilledButton.styleFrom(
                    backgroundColor: Theme.of(context).colorScheme.primary,
                    foregroundColor: Theme.of(context).colorScheme.onPrimary,
                  )
                : null,
            onPressed: () => setState(() => _winner = side),
            child: Text(label),
          ),
        ),
      );
    }

    return Row(
      children: [
        button('player', 'We won', const ValueKey('winnerPlayer')),
        button('opponent', 'They won', const ValueKey('winnerOpponent')),
      ],
    );
  }

  Widget _chipWrap<T>({
    required Iterable<MapEntry<String, String>> options,
    required String? selected,
    required ValueChanged<String?> onChanged,
  }) {
    return Wrap(
      spacing: 6,
      runSpacing: 0,
      children: [
        for (final option in options)
          ChoiceChip(
            label: Text(option.value),
            selected: selected == option.key,
            onSelected: (on) => onChanged(on ? option.key : null),
          ),
      ],
    );
  }

  String _shotLabel(String shot) =>
      shot[0].toUpperCase() + shot.substring(1);

  static const _zoneLabels = {
    'frontLeft': 'Front L',
    'frontRight': 'Front R',
    'midLeft': 'Mid L',
    'midRight': 'Mid R',
    'rearLeft': 'Rear L',
    'rearRight': 'Rear R',
  };

  Widget _tagForm(List<PointRecord> points) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _winnerButtons(),
        const SizedBox(height: 10),
        Text('How did it end?', style: Theme.of(context).textTheme.bodySmall),
        _chipWrap(
          options: _endingTypeLabels.entries,
          selected: _endingType,
          onChanged: (v) => setState(() => _endingType = v),
        ),
        const SizedBox(height: 6),
        Text(
          'Ending shot (optional)',
          style: Theme.of(context).textTheme.bodySmall,
        ),
        _chipWrap(
          options: [
            for (final shot in PointRecord.endingShots)
              MapEntry(shot, _shotLabel(shot)),
          ],
          selected: _endingShot,
          onChanged: (v) => setState(() => _endingShot = v),
        ),
        const SizedBox(height: 6),
        Text(
          'Where it landed (optional)',
          style: Theme.of(context).textTheme.bodySmall,
        ),
        _chipWrap(
          options: _zoneLabels.entries,
          selected: _endingZone,
          onChanged: (v) => setState(() => _endingZone = v),
        ),
        if (_endingZone != null)
          Padding(
            padding: const EdgeInsets.only(top: 4),
            child: SegmentedButton<String>(
              segments: const [
                ButtonSegment(value: 'player', label: Text('Our side')),
                ButtonSegment(value: 'opponent', label: Text('Their side')),
              ],
              emptySelectionAllowed: true,
              selected: {if (_endingSide != null) _endingSide!},
              onSelectionChanged: (sel) => setState(
                () => _endingSide = sel.isEmpty ? null : sel.first,
              ),
            ),
          ),
        const SizedBox(height: 12),
        SizedBox(
          width: double.infinity,
          child: ElevatedButton(
            key: const ValueKey('savePointButton'),
            onPressed: _canSave ? _savePoint : null,
            child: const Text('Save point'),
          ),
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Tag points — vs ${widget.log.opponent}'),
        actions: [
          Consumer<PointRecordProvider>(
            builder: (context, provider, _) => IconButton(
              tooltip: 'Undo last point',
              icon: const Icon(Icons.undo),
              onPressed: provider.points.isEmpty
                  ? null
                  : () => provider.undoLast(),
            ),
          ),
        ],
      ),
      body: Consumer<PointRecordProvider>(
        builder: (context, provider, _) {
          final points = provider.points;
          final needsFirstServer = points.isEmpty && _firstServer == null;
          return ListView(
            padding: const EdgeInsets.all(12),
            children: [
              _videoView(),
              if (_videoReady) VideoScrubber(controller: _video),
              const SizedBox(height: 8),
              _header(points),
              const SizedBox(height: 8),
              if (needsFirstServer)
                _firstServerPrompt()
              else
                _tagForm(points),
            ],
          );
        },
      ),
    );
  }
}
