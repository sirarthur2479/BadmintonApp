import 'package:flutter/material.dart';

/// Match-log list body (fleshed out in the next slice).
class MatchLogsTab extends StatelessWidget {
  const MatchLogsTab({super.key});

  @override
  Widget build(BuildContext context) {
    return const SizedBox.shrink();
  }
}

/// Stand-in until LogMatchScreen lands (TASK-040).
class LogMatchPlaceholder extends StatelessWidget {
  const LogMatchPlaceholder({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(appBar: AppBar(title: const Text('Log Match')));
  }
}
