import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import 'package:share_plus/share_plus.dart';
import '../providers/session_provider.dart';
import '../services/export_service.dart';
import '../theme/app_theme.dart';

/// Bulk Markdown export: pick a date range, see how many sessions it covers,
/// send the combined Markdown to the system share sheet.
class ExportScreen extends StatefulWidget {
  const ExportScreen({super.key});

  @override
  State<ExportScreen> createState() => _ExportScreenState();
}

class _ExportScreenState extends State<ExportScreen> {
  late DateTime _from;
  late DateTime _to;

  @override
  void initState() {
    super.initState();
    final now = DateTime.now();
    _to = DateTime(now.year, now.month, now.day);
    _from = _to.subtract(const Duration(days: 30));
  }

  Future<void> _pickDate({required bool isFrom}) async {
    final picked = await showDatePicker(
      context: context,
      initialDate: isFrom ? _from : _to,
      firstDate: DateTime(2020),
      lastDate: DateTime.now(),
    );
    if (picked == null) return;
    setState(() {
      if (isFrom) {
        _from = picked;
        if (_to.isBefore(_from)) _to = _from;
      } else {
        _to = picked;
        if (_to.isBefore(_from)) _from = _to;
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final fmt = DateFormat('EEE, d MMM yyyy');
    final provider = context.watch<SessionProvider>();
    final endExclusive = _to.add(const Duration(days: 1));
    final inRange = provider.sessions
        .where((s) => !s.date.isBefore(_from) && s.date.isBefore(endExclusive))
        .toList();

    return Scaffold(
      appBar: AppBar(title: const Text('Export Training Log')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          ListTile(
            contentPadding: EdgeInsets.zero,
            leading: const Icon(Icons.today, color: AppTheme.primary),
            title: const Text('From'),
            subtitle: Text(fmt.format(_from)),
            trailing: const Icon(
              Icons.edit,
              size: 18,
              color: AppTheme.textSecondary,
            ),
            onTap: () => _pickDate(isFrom: true),
          ),
          ListTile(
            contentPadding: EdgeInsets.zero,
            leading: const Icon(Icons.event, color: AppTheme.primary),
            title: const Text('To'),
            subtitle: Text(fmt.format(_to)),
            trailing: const Icon(
              Icons.edit,
              size: 18,
              color: AppTheme.textSecondary,
            ),
            onTap: () => _pickDate(isFrom: false),
          ),
          const Divider(),
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 12),
            child: Text(
              '${inRange.length} sessions in range',
              style: Theme.of(context).textTheme.titleMedium,
            ),
          ),
          ElevatedButton.icon(
            onPressed: inRange.isEmpty
                ? null
                : () => SharePlus.instance.share(
                    ShareParams(
                      text: ExportService.bulkExport(
                        sessions: provider.sessions,
                        from: _from,
                        to: _to,
                      ),
                      subject: 'Training log export',
                    ),
                  ),
            icon: const Icon(Icons.ios_share),
            label: const Text('Export as Markdown'),
          ),
          const SizedBox(height: 8),
          const Text(
            'Markdown works well for sharing with a coach or pasting into '
            'an AI analysis chat.',
            style: TextStyle(fontSize: 12, color: AppTheme.textSecondary),
          ),
        ],
      ),
    );
  }
}
