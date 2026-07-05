import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:uuid/uuid.dart';
import 'package:image_picker/image_picker.dart';
import 'package:intl/intl.dart';
import '../../models/session.dart';
import '../../providers/session_provider.dart';
import '../../services/photo_store.dart';
import '../../theme/app_theme.dart';

class LogSessionScreen extends StatefulWidget {
  const LogSessionScreen({super.key});

  @override
  State<LogSessionScreen> createState() => _LogSessionScreenState();
}

class _LogSessionScreenState extends State<LogSessionScreen> {
  DateTime _date = DateTime.now();
  int _duration = 60;
  final Set<String> _selectedDrills = {};
  int _intensity = 3;
  final _notesController = TextEditingController();
  String? _photoPath;
  bool _saving = false;

  @override
  void dispose() {
    _notesController.dispose();
    super.dispose();
  }

  Future<void> _pickDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _date,
      firstDate: DateTime(2020),
      lastDate: DateTime.now(),
    );
    if (picked != null) setState(() => _date = picked);
  }

  Future<void> _pickPhoto() async {
    final picker = ImagePicker();
    final file = await picker.pickImage(source: ImageSource.gallery, imageQuality: 80);
    if (file != null) setState(() => _photoPath = file.path);
  }

  Future<void> _save() async {
    if (_selectedDrills.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Select at least one drill type.')),
      );
      return;
    }
    setState(() => _saving = true);
    final provider = context.read<SessionProvider>();
    final id = const Uuid().v4();
    // The picker returns a purgeable temp-cache path; copy the photo into
    // app documents before persisting. Web keeps the blob URL as-is.
    String? storedPhoto = _photoPath;
    if (_photoPath != null && !kIsWeb) {
      storedPhoto = await PhotoStore.instance.savePhoto(_photoPath!, id);
    }
    final session = TrainingSession(
      id: id,
      date: _date,
      durationMinutes: _duration,
      drills: _selectedDrills.toList(),
      intensity: _intensity,
      notes: _notesController.text.trim(),
      photoPath: storedPhoto,
    );
    await provider.addSession(session);
    if (mounted) Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Log Session')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          // Date
          _SectionLabel('Date'),
          ListTile(
            contentPadding: EdgeInsets.zero,
            leading: const Icon(Icons.calendar_today, color: AppTheme.primary),
            title: Text(DateFormat('EEE, d MMM yyyy').format(_date)),
            trailing: const Icon(Icons.edit, size: 18, color: AppTheme.textSecondary),
            onTap: _pickDate,
          ),
          const Divider(),

          // Duration
          _SectionLabel('Duration'),
          Row(
            children: [
              Expanded(
                child: Slider(
                  value: _duration.toDouble(),
                  min: 15,
                  max: 180,
                  divisions: 33,
                  activeColor: AppTheme.primary,
                  label: '$_duration min',
                  onChanged: (v) => setState(() => _duration = v.round()),
                ),
              ),
              SizedBox(
                width: 60,
                child: Text(
                  '$_duration min',
                  style: const TextStyle(fontWeight: FontWeight.w600),
                ),
              ),
            ],
          ),
          const Divider(),

          // Drills
          _SectionLabel('Drills practiced'),
          const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: kDrillTypes.map((drill) {
              final selected = _selectedDrills.contains(drill);
              return FilterChip(
                label: Text(drill),
                selected: selected,
                onSelected: (on) => setState(() {
                  if (on) {
                    _selectedDrills.add(drill);
                  } else {
                    _selectedDrills.remove(drill);
                  }
                }),
                selectedColor: AppTheme.primary,
                checkmarkColor: Colors.white,
                labelStyle: TextStyle(
                  color: selected ? Colors.white : AppTheme.textPrimary,
                ),
              );
            }).toList(),
          ),
          const SizedBox(height: 8),
          const Divider(),

          // Intensity
          _SectionLabel('Intensity'),
          Row(
            children: [
              const Text('Easy', style: TextStyle(fontSize: 12, color: AppTheme.textSecondary)),
              Expanded(
                child: Slider(
                  value: _intensity.toDouble(),
                  min: 1,
                  max: 5,
                  divisions: 4,
                  activeColor: AppTheme.intensityColor(_intensity),
                  label: '$_intensity / 5',
                  onChanged: (v) => setState(() => _intensity = v.round()),
                ),
              ),
              const Text('Hard', style: TextStyle(fontSize: 12, color: AppTheme.textSecondary)),
            ],
          ),
          const Divider(),

          // Notes
          _SectionLabel('Notes / Coach feedback'),
          const SizedBox(height: 8),
          TextField(
            controller: _notesController,
            maxLines: 4,
            decoration: const InputDecoration(
              hintText: 'What did you work on? Any coach feedback?',
            ),
          ),
          const SizedBox(height: 16),

          // Photo
          Row(
            children: [
              OutlinedButton.icon(
                onPressed: _pickPhoto,
                icon: const Icon(Icons.photo_camera_outlined),
                label: Text(_photoPath == null ? 'Add Photo' : 'Change Photo'),
                style: OutlinedButton.styleFrom(foregroundColor: AppTheme.primary),
              ),
              if (_photoPath != null) ...[
                const SizedBox(width: 8),
                const Icon(Icons.check_circle, color: AppTheme.primary, size: 20),
                const SizedBox(width: 4),
                const Text('Photo added', style: TextStyle(fontSize: 12, color: AppTheme.primary)),
              ],
            ],
          ),
          const SizedBox(height: 32),

          // Save
          ElevatedButton(
            onPressed: _saving ? null : _save,
            child: _saving
                ? const SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(
                        strokeWidth: 2, color: Colors.white),
                  )
                : const Text('Save Session'),
          ),
          const SizedBox(height: 16),
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
      padding: const EdgeInsets.only(top: 8, bottom: 4),
      child: Text(
        text,
        style: const TextStyle(
          fontWeight: FontWeight.w600,
          fontSize: 14,
          color: AppTheme.textSecondary,
        ),
      ),
    );
  }
}
