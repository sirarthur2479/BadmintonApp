import 'package:flutter/material.dart';

import '../services/tagging_video_controller.dart';

/// Scrub / step / speed controls for the tagging screen, built over the
/// [TaggingVideoController] seam only — no direct video_player use, so
/// widget tests drive it with the hand-driven fake.
class VideoScrubber extends StatefulWidget {
  const VideoScrubber({super.key, required this.controller});

  final TaggingVideoController controller;

  @override
  State<VideoScrubber> createState() => _VideoScrubberState();
}

class _VideoScrubberState extends State<VideoScrubber> {
  TaggingVideoController get _controller => widget.controller;

  static const _speeds = [0.25, 0.5, 1.0];

  String _format(Duration d) {
    final minutes = d.inMinutes.toString().padLeft(2, '0');
    final seconds = (d.inSeconds % 60).toString().padLeft(2, '0');
    return '$minutes:$seconds';
  }

  Future<void> _run(Future<void> Function() action) async {
    await action();
    if (mounted) setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    final total = _controller.duration;
    return ValueListenableBuilder<Duration>(
      valueListenable: _controller.position,
      builder: (context, position, _) {
        final totalMs = total.inMilliseconds;
        final fraction = totalMs == 0
            ? 0.0
            : (position.inMilliseconds / totalMs).clamp(0.0, 1.0);
        return Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Slider(
              value: fraction,
              onChanged: (v) => _run(
                () => _controller.seekTo(
                  Duration(milliseconds: (v * totalMs).round()),
                ),
              ),
            ),
            Row(
              children: [
                Text(
                  '${_format(position)} / ${_format(total)}',
                  style: Theme.of(context).textTheme.bodySmall,
                ),
                const Spacer(),
                IconButton(
                  tooltip: 'Back 1 second',
                  icon: const Icon(Icons.replay),
                  onPressed: () => _run(
                    () => _controller.seekTo(
                      stepTarget(
                        _controller.position.value,
                        -1,
                        const Duration(seconds: 1),
                        total,
                      ),
                    ),
                  ),
                ),
                IconButton(
                  tooltip: 'Back 1 frame',
                  icon: const Icon(Icons.keyboard_arrow_left),
                  onPressed: () => _run(() => _controller.stepFrames(-1)),
                ),
                IconButton(
                  tooltip: _controller.isPlaying ? 'Pause' : 'Play',
                  icon: Icon(
                    _controller.isPlaying ? Icons.pause : Icons.play_arrow,
                  ),
                  onPressed: () => _run(
                    () => _controller.isPlaying
                        ? _controller.pause()
                        : _controller.play(),
                  ),
                ),
                IconButton(
                  tooltip: 'Forward 1 frame',
                  icon: const Icon(Icons.keyboard_arrow_right),
                  onPressed: () => _run(() => _controller.stepFrames(1)),
                ),
                IconButton(
                  tooltip: 'Forward 1 second',
                  icon: const Icon(Icons.forward),
                  onPressed: () => _run(
                    () => _controller.seekTo(
                      stepTarget(
                        _controller.position.value,
                        1,
                        const Duration(seconds: 1),
                        total,
                      ),
                    ),
                  ),
                ),
                PopupMenuButton<double>(
                  tooltip: 'Playback speed',
                  icon: const Icon(Icons.speed),
                  onSelected: (speed) => _run(
                    () => _controller.setSpeed(speed),
                  ),
                  itemBuilder: (context) => [
                    for (final speed in _speeds)
                      PopupMenuItem(
                        value: speed,
                        child: Text(
                          speed == 1.0 ? '1×' : '$speed×',
                        ),
                      ),
                  ],
                ),
              ],
            ),
          ],
        );
      },
    );
  }
}
