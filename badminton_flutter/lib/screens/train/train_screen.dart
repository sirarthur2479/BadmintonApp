import 'package:flutter/material.dart';

import 'log_match_screen.dart';
import 'log_session_screen.dart';
import 'match_logs_tab.dart';
import 'session_history_screen.dart';

/// The Train tab: Sessions (training history) and Match Logs side by side.
class TrainScreen extends StatefulWidget {
  const TrainScreen({super.key});

  @override
  State<TrainScreen> createState() => _TrainScreenState();
}

class _TrainScreenState extends State<TrainScreen>
    with SingleTickerProviderStateMixin {
  late final TabController _tabs;

  @override
  void initState() {
    super.initState();
    _tabs = TabController(length: 2, vsync: this);
    // The FAB's target depends on the active tab.
    _tabs.addListener(() => setState(() {}));
  }

  @override
  void dispose() {
    _tabs.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final onSessionsTab = _tabs.index == 0;
    return Scaffold(
      appBar: AppBar(
        title: const Text('Train'),
        actions: [if (onSessionsTab) const SessionExportAction()],
        bottom: TabBar(
          controller: _tabs,
          tabs: const [
            Tab(text: 'Sessions'),
            Tab(text: 'Match Logs'),
          ],
        ),
      ),
      body: TabBarView(
        controller: _tabs,
        children: const [SessionHistoryBody(), MatchLogsTab()],
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () => Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) => onSessionsTab
                ? const LogSessionScreen()
                : const LogMatchScreen(),
          ),
        ),
        child: const Icon(Icons.add),
      ),
    );
  }
}
