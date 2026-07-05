import 'package:flutter/material.dart';

/// Shared confirmation dialog for destructive actions.
/// Returns true only when the user explicitly confirms.
Future<bool> confirmDelete(
  BuildContext context, {
  required String title,
  String message = 'This cannot be undone.',
}) async {
  final confirmed = await showDialog<bool>(
    context: context,
    builder: (ctx) => AlertDialog(
      title: Text(title),
      content: Text(message),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(ctx, false),
          child: const Text('Cancel'),
        ),
        TextButton(
          onPressed: () => Navigator.pop(ctx, true),
          child: const Text('Delete', style: TextStyle(color: Colors.red)),
        ),
      ],
    ),
  );
  return confirmed ?? false;
}
