import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:uuid/uuid.dart';
import 'package:image_picker/image_picker.dart';
import 'package:intl/intl.dart';
import 'package:share_plus/share_plus.dart';
import '../../models/reflection_data.dart';
import '../../models/session.dart';
import '../../providers/session_provider.dart';
import '../../services/export_service.dart';
import '../../services/photo_store.dart';
import '../../theme/app_theme.dart';
import '../../widgets/confirm_delete.dart';
import '../../widgets/star_rating.dart';

class LogSessionScreen extends StatefulWidget {
  /// When non-null the screen edits this session instead of creating one.
  final TrainingSession? session;

  const LogSessionScreen({super.key, this.session});

  @override
  State<LogSessionScreen> createState() => _LogSessionScreenState();
}

class _LogSessionScreenState extends State<LogSessionScreen> {
  DateTime _date = DateTime.now();
  int _duration = 60;
  final Set<String> _selectedDrills = {};
  final _goalController = TextEditingController();
  final _playerRemarksController = TextEditingController();
  final _coachRemarksController = TextEditingController();
  final List<TextEditingController> _answerControllers = List.generate(
    kReflectionQuestions.length,
    (_) => TextEditingController(),
  );
  int _goalScore = 3;
  final _notesController = TextEditingController();
  String? _photoPath;
  bool _saving = false;

  bool get _isEditing => widget.session != null;

  @override
  void initState() {
    super.initState();
    final session = widget.session;
    if (session != null) {
      _date = session.date;
      _duration = session.durationMinutes;
      _selectedDrills.addAll(session.drills);
      _notesController.text = session.notes;
      _photoPath = session.photoPath;
      _goalController.text = session.sessionGoal;
      _goalScore = session.goalAchievementScore;
      _playerRemarksController.text = session.playerRemarks;
      _coachRemarksController.text = session.coachRemarks;
      for (final answer in decodeReflectionAnswers(
        session.reflectionAnswersJson,
      )) {
        final i = kReflectionQuestions.indexOf(answer.questionKey);
        if (i >= 0) _answerControllers[i].text = answer.answer;
      }
    }
  }

  @override
  void dispose() {
    _goalController.dispose();
    _playerRemarksController.dispose();
    _coachRemarksController.dispose();
    for (final c in _answerControllers) {
      c.dispose();
    }
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
    final file = await picker.pickImage(
      source: ImageSource.gallery,
      imageQuality: 80,
    );
    if (file != null) setState(() => _photoPath = file.path);
  }

  Future<void> _promptNewTag() async {
    final controller = TextEditingController();
    final name = await showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('New drill tag'),
        content: TextField(
          controller: controller,
          autofocus: true,
          decoration: const InputDecoration(hintText: 'e.g. Deception'),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, controller.text),
            child: const Text('Add'),
          ),
        ],
      ),
    );
    if (name != null && mounted) {
      await context.read<SessionProvider>().addCustomTag(name);
    }
    controller.dispose();
  }

  Future<void> _promptDeleteTag(String tag) async {
    final confirmed = await confirmDelete(
      context,
      title: 'Delete tag "$tag"?',
      message: 'Sessions already logged with it keep the tag.',
    );
    if (confirmed && mounted) {
      await context.read<SessionProvider>().deleteCustomTag(tag);
      setState(() => _selectedDrills.remove(tag));
    }
  }

  String _encodeAnswers() {
    final answers = <ReflectionAnswer>[
      for (var i = 0; i < kReflectionQuestions.length; i++)
        if (_answerControllers[i].text.trim().isNotEmpty)
          ReflectionAnswer(
            questionKey: kReflectionQuestions[i],
            answer: _answerControllers[i].text.trim(),
          ),
    ];
    return encodeReflectionAnswers(answers);
  }

  Future<void> _save() async {
    if (_goalController.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Set a session goal first.')),
      );
      return;
    }
    if (_selectedDrills.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Select at least one drill type.')),
      );
      return;
    }
    setState(() => _saving = true);
    final provider = context.read<SessionProvider>();
    final id = widget.session?.id ?? const Uuid().v4();
    // The picker returns a purgeable temp-cache path; copy the photo into
    // app documents before persisting. Web keeps the blob URL as-is.
    // In edit mode an untouched photo path is already stored — don't re-copy.
    String? storedPhoto = _photoPath;
    final photoChanged = _photoPath != widget.session?.photoPath;
    if (_photoPath != null && !kIsWeb && (!_isEditing || photoChanged)) {
      storedPhoto = await PhotoStore.instance.savePhoto(_photoPath!, id);
    }
    if (_isEditing) {
      final oldPhoto = widget.session!.photoPath;
      // copyWith keeps the legacy intensity rating untouched.
      final updated = widget.session!.copyWith(
        date: _date,
        durationMinutes: _duration,
        drills: _selectedDrills.toList(),
        notes: _notesController.text.trim(),
        photoPath: storedPhoto,
        sessionGoal: _goalController.text.trim(),
        goalAchievementScore: _goalScore,
        playerRemarks: _playerRemarksController.text.trim(),
        coachRemarks: _coachRemarksController.text.trim(),
        reflectionAnswersJson: _encodeAnswers(),
      );
      await provider.updateSession(updated);
      if (photoChanged && oldPhoto != null && !kIsWeb) {
        await PhotoStore.instance.deletePhoto(oldPhoto);
      }
    } else {
      final session = TrainingSession(
        id: id,
        date: _date,
        durationMinutes: _duration,
        drills: _selectedDrills.toList(),
        notes: _notesController.text.trim(),
        photoPath: storedPhoto,
        sessionGoal: _goalController.text.trim(),
        goalAchievementScore: _goalScore,
        playerRemarks: _playerRemarksController.text.trim(),
        coachRemarks: _coachRemarksController.text.trim(),
        reflectionAnswersJson: _encodeAnswers(),
      );
      await provider.addSession(session);
    }
    if (mounted) Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) {
    final customTags = context.watch<SessionProvider>().customTags;
    // Built-ins, the user's tags, then any legacy drill names that survive
    // only on the session being edited.
    final drillOptions = [
      ...kDrillTypes,
      ...customTags,
      ...?widget.session?.drills.where(
        (d) => !kDrillTypes.contains(d) && !customTags.contains(d),
      ),
    ];
    return Scaffold(
      appBar: AppBar(
        title: Text(_isEditing ? 'Edit Session' : 'Log Session'),
        actions: [
          if (_isEditing)
            IconButton(
              icon: const Icon(Icons.ios_share),
              tooltip: 'Share as Markdown',
              onPressed: () => SharePlus.instance.share(
                ShareParams(
                  text: ExportService.sessionToMarkdown(widget.session!),
                  subject: 'Training session',
                ),
              ),
            ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          // Date
          _SectionLabel('Date'),
          ListTile(
            contentPadding: EdgeInsets.zero,
            leading: const Icon(Icons.calendar_today, color: AppTheme.primary),
            title: Text(DateFormat('EEE, d MMM yyyy').format(_date)),
            trailing: const Icon(
              Icons.edit,
              size: 18,
              color: AppTheme.textSecondary,
            ),
            onTap: _pickDate,
          ),
          const Divider(),

          // Session goal
          _SectionLabel('Session goal'),
          const SizedBox(height: 8),
          TextField(
            key: const ValueKey('goalField'),
            controller: _goalController,
            decoration: const InputDecoration(
              hintText: 'What do you want to achieve today?',
            ),
          ),
          const SizedBox(height: 8),
          const Divider(),

          // Drills
          _SectionLabel('Drills practiced'),
          const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              ...drillOptions.map((drill) {
                final selected = _selectedDrills.contains(drill);
                final chip = FilterChip(
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
                // Only the user's own tags can be long-press deleted.
                if (!customTags.contains(drill)) return chip;
                return GestureDetector(
                  onLongPress: () => _promptDeleteTag(drill),
                  child: chip,
                );
              }),
              ActionChip(
                avatar: const Icon(Icons.add, size: 18),
                label: const Text('New tag'),
                onPressed: _promptNewTag,
              ),
            ],
          ),
          const SizedBox(height: 8),
          const Divider(),

          // Reflection
          _SectionLabel('Reflection'),
          const SizedBox(height: 4),
          for (var i = 0; i < kReflectionQuestions.length; i++) ...[
            Padding(
              padding: const EdgeInsets.only(top: 8, bottom: 4),
              child: Text(
                kReflectionQuestions[i],
                style: const TextStyle(
                  fontSize: 13,
                  color: AppTheme.textPrimary,
                ),
              ),
            ),
            TextField(
              key: ValueKey('reflection-$i'),
              controller: _answerControllers[i],
              maxLines: 3,
              minLines: 1,
              decoration: const InputDecoration(isDense: true),
            ),
          ],
          const SizedBox(height: 16),
          Row(
            children: [
              const Expanded(child: Text('Goal achievement')),
              StarRating(
                value: _goalScore,
                onChanged: (v) => setState(() => _goalScore = v),
              ),
            ],
          ),
          const SizedBox(height: 12),
          _SectionLabel('Done well (player)'),
          TextField(
            key: const ValueKey('playerRemarks'),
            controller: _playerRemarksController,
            decoration: const InputDecoration(
              hintText: 'What went well from your side?',
            ),
          ),
          const SizedBox(height: 12),
          _SectionLabel('Coach remarks'),
          TextField(
            key: const ValueKey('coachRemarks'),
            controller: _coachRemarksController,
            decoration: const InputDecoration(
              hintText: 'What did the coach highlight?',
            ),
          ),
          const SizedBox(height: 8),
          const Divider(),

          // Advanced: duration + free notes
          ExpansionTile(
            title: const Text('Advanced'),
            tilePadding: EdgeInsets.zero,
            childrenPadding: EdgeInsets.zero,
            children: [
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
              _SectionLabel('Notes / Coach feedback'),
              const SizedBox(height: 8),
              TextField(
                controller: _notesController,
                maxLines: 4,
                decoration: const InputDecoration(
                  hintText: 'Anything else worth remembering?',
                ),
              ),
              const SizedBox(height: 8),
            ],
          ),
          const SizedBox(height: 16),

          // Photo
          Row(
            children: [
              OutlinedButton.icon(
                onPressed: _pickPhoto,
                icon: const Icon(Icons.photo_camera_outlined),
                label: Text(_photoPath == null ? 'Add Photo' : 'Change Photo'),
                style: OutlinedButton.styleFrom(
                  foregroundColor: AppTheme.primary,
                ),
              ),
              if (_photoPath != null) ...[
                const SizedBox(width: 8),
                const Icon(
                  Icons.check_circle,
                  color: AppTheme.primary,
                  size: 20,
                ),
                const SizedBox(width: 4),
                const Text(
                  'Photo added',
                  style: TextStyle(fontSize: 12, color: AppTheme.primary),
                ),
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
                      strokeWidth: 2,
                      color: Colors.white,
                    ),
                  )
                : Text(_isEditing ? 'Update Session' : 'Save Session'),
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
