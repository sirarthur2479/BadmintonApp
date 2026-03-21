import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:image_picker/image_picker.dart';
import '../../models/player_profile.dart';
import '../../providers/profile_provider.dart';
import '../../theme/app_theme.dart';
import 'progress_screen.dart';
import 'tournament_screen.dart';

class ProfileScreen extends StatefulWidget {
  const ProfileScreen({super.key});

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  final _nameCtrl = TextEditingController();
  final _clubCtrl = TextEditingController();
  final _shortGoalCtrl = TextEditingController();
  final _longGoalCtrl = TextEditingController();
  int? _age;
  int? _yearsPlaying;
  String _playingStyle = 'all-round';
  String _preferredGrip = 'forehand';
  String? _photoPath;
  bool _editing = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _loadFromProvider();
  }

  void _loadFromProvider() {
    final profile = context.read<ProfileProvider>().profile;
    _nameCtrl.text = profile.name;
    _clubCtrl.text = profile.club;
    _shortGoalCtrl.text = profile.shortTermGoal;
    _longGoalCtrl.text = profile.longTermGoal;
    _age = profile.age;
    _yearsPlaying = profile.yearsPlaying;
    _playingStyle = profile.playingStyle;
    _preferredGrip = profile.preferredGrip;
    _photoPath = profile.photoPath;
  }

  Future<void> _pickPhoto() async {
    final picker = ImagePicker();
    final file =
        await picker.pickImage(source: ImageSource.gallery, imageQuality: 80);
    if (file != null) setState(() => _photoPath = file.path);
  }

  Future<void> _save() async {
    final profile = PlayerProfile(
      name: _nameCtrl.text.trim(),
      age: _age,
      club: _clubCtrl.text.trim(),
      yearsPlaying: _yearsPlaying,
      photoPath: _photoPath,
      playingStyle: _playingStyle,
      preferredGrip: _preferredGrip,
      shortTermGoal: _shortGoalCtrl.text.trim(),
      longTermGoal: _longGoalCtrl.text.trim(),
    );
    await context.read<ProfileProvider>().saveProfile(profile);
    setState(() => _editing = false);
    if (mounted) {
      ScaffoldMessenger.of(context)
          .showSnackBar(const SnackBar(content: Text('Profile saved!')));
    }
  }

  @override
  void dispose() {
    _nameCtrl.dispose();
    _clubCtrl.dispose();
    _shortGoalCtrl.dispose();
    _longGoalCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Profile'),
        actions: [
          TextButton(
            onPressed: () {
              if (_editing) {
                _save();
              } else {
                setState(() => _editing = true);
              }
            },
            child: Text(
              _editing ? 'Save' : 'Edit',
              style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w600),
            ),
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          // Avatar
          Center(
            child: GestureDetector(
              onTap: _editing ? _pickPhoto : null,
              child: Stack(
                children: [
                  CircleAvatar(
                    radius: 48,
                    backgroundColor: const Color(0xFFE8F5E9),
                    backgroundImage:
                        _photoPath != null ? NetworkImage(_photoPath!) : null,
                    child: _photoPath == null
                        ? const Icon(Icons.person, size: 48, color: AppTheme.primary)
                        : null,
                  ),
                  if (_editing)
                    Positioned(
                      bottom: 0,
                      right: 0,
                      child: Container(
                        padding: const EdgeInsets.all(4),
                        decoration: const BoxDecoration(
                          color: AppTheme.primary,
                          shape: BoxShape.circle,
                        ),
                        child: const Icon(Icons.camera_alt,
                            size: 16, color: Colors.white),
                      ),
                    ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 24),

          // Name
          _field('Name', _nameCtrl, enabled: _editing),
          const SizedBox(height: 12),
          _field('Club', _clubCtrl, enabled: _editing),
          const SizedBox(height: 12),

          // Age + Years playing
          Row(
            children: [
              Expanded(
                child: _numberField('Age', _age, _editing,
                    (v) => setState(() => _age = v)),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _numberField('Years playing', _yearsPlaying, _editing,
                    (v) => setState(() => _yearsPlaying = v)),
              ),
            ],
          ),
          const SizedBox(height: 16),

          // Playing style
          _dropdownField(
            'Playing style',
            _playingStyle,
            kPlayingStyles,
            _editing,
            (v) => setState(() => _playingStyle = v!),
          ),
          const SizedBox(height: 12),

          // Preferred grip
          _dropdownField(
            'Preferred grip',
            _preferredGrip,
            kGripTypes,
            _editing,
            (v) => setState(() => _preferredGrip = v!),
          ),
          const SizedBox(height: 16),

          _field('Short-term goal', _shortGoalCtrl,
              enabled: _editing, maxLines: 2),
          const SizedBox(height: 12),
          _field('Long-term goal', _longGoalCtrl,
              enabled: _editing, maxLines: 2),
          const SizedBox(height: 28),

          // Navigation links
          _navTile(
            context,
            icon: Icons.bar_chart,
            label: 'Progress & Charts',
            onTap: () => Navigator.push(context,
                MaterialPageRoute(builder: (_) => const ProgressScreen())),
          ),
          _navTile(
            context,
            icon: Icons.emoji_events_outlined,
            label: 'Tournament History',
            onTap: () => Navigator.push(context,
                MaterialPageRoute(builder: (_) => const TournamentScreen())),
          ),
          const SizedBox(height: 16),
        ],
      ),
    );
  }

  Widget _field(String label, TextEditingController ctrl,
      {bool enabled = true, int maxLines = 1}) {
    return TextField(
      controller: ctrl,
      enabled: enabled,
      maxLines: maxLines,
      decoration: InputDecoration(labelText: label),
    );
  }

  Widget _numberField(String label, int? value, bool enabled, ValueChanged<int?> onChanged) {
    return TextFormField(
      initialValue: value?.toString() ?? '',
      enabled: enabled,
      keyboardType: TextInputType.number,
      decoration: InputDecoration(labelText: label),
      onChanged: (v) => onChanged(int.tryParse(v)),
    );
  }

  Widget _dropdownField(String label, String value, List<String> options,
      bool enabled, ValueChanged<String?> onChanged) {
    return InputDecorator(
      decoration: InputDecoration(
        labelText: label,
        enabled: enabled,
      ),
      child: DropdownButtonHideUnderline(
        child: DropdownButton<String>(
          value: value,
          isDense: true,
          onChanged: enabled ? onChanged : null,
          items: options
              .map((o) => DropdownMenuItem(
                    value: o,
                    child: Text(
                      o[0].toUpperCase() + o.substring(1),
                    ),
                  ))
              .toList(),
        ),
      ),
    );
  }

  Widget _navTile(BuildContext context,
      {required IconData icon,
      required String label,
      required VoidCallback onTap}) {
    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      child: ListTile(
        leading: Icon(icon, color: AppTheme.primary),
        title: Text(label),
        trailing: const Icon(Icons.chevron_right, color: AppTheme.textSecondary),
        onTap: onTap,
      ),
    );
  }
}
