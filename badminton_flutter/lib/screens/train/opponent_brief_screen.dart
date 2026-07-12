import 'package:flutter/material.dart';
import 'package:share_plus/share_plus.dart';

import '../../theme/app_theme.dart';

/// The tactical brief viewer (pool #10): Markdown rendered as selectable
/// text (analysis-report-screen pattern — briefs are headings and bullet
/// lists, readable as-is), with a share/export action. When the LLM wasn't
/// reachable the metrics-only brief is shown with an unobtrusive note.
class OpponentBriefScreen extends StatelessWidget {
  const OpponentBriefScreen({
    super.key,
    required this.displayName,
    required this.markdown,
    this.aiUnavailable = false,
  });

  final String displayName;
  final String markdown;
  final bool aiUnavailable;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Brief — $displayName'),
        actions: [
          IconButton(
            tooltip: 'Share',
            icon: const Icon(Icons.ios_share),
            onPressed: () => SharePlus.instance.share(
              ShareParams(
                text: markdown,
                subject: 'Tactical brief — $displayName',
              ),
            ),
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          if (aiUnavailable)
            const Card(
              child: Padding(
                padding: EdgeInsets.all(12),
                child: Text(
                  'AI narrative unavailable — showing metrics only. Start '
                  'the analysis server (and Ollama) to get a full gameplan.',
                  style: TextStyle(color: AppTheme.textSecondary),
                ),
              ),
            ),
          SelectableText(markdown, style: const TextStyle(height: 1.5)),
        ],
      ),
    );
  }
}
