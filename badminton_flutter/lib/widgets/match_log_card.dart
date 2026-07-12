import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../models/match_log.dart';
import '../theme/app_theme.dart';

class MatchLogCard extends StatelessWidget {
  final MatchLog log;
  final VoidCallback? onTap;
  final VoidCallback? onDelete;

  const MatchLogCard({super.key, required this.log, this.onTap, this.onDelete});

  @override
  Widget build(BuildContext context) {
    return Card(
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Text(
                      DateFormat('EEE, d MMM yyyy').format(log.date),
                      style: Theme.of(context).textTheme.titleMedium,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 6),
              Text('vs ${log.opponent}'),
              if (log.eventContext.isNotEmpty)
                Text(
                  log.eventContext,
                  style: const TextStyle(color: AppTheme.textSecondary),
                ),
            ],
          ),
        ),
      ),
    );
  }
}
