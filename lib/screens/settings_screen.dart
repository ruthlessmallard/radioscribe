import 'package:audioplayers/audioplayers.dart';
import 'package:flutter/material.dart';
import '../models/keyword_config.dart';
import '../services/settings_service.dart';
import '../theme/app_theme.dart';

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  late SettingsService _settingsService;
  late KeywordConfig _config;
  bool _loaded = false;
  bool _dirty = false;
  final AudioPlayer _testPlayer = AudioPlayer();

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    _settingsService = await SettingsService.getInstance();
    setState(() {
      _config = _settingsService.config;
      _loaded = true;
    });
  }

  @override
  void dispose() {
    _testPlayer.dispose();
    super.dispose();
  }

  static const _audioCtx = AudioContext(
    android: AudioContextAndroid(
      audioFocus: AndroidAudioFocus.none,
      contentType: AndroidContentType.sonification,
      usageType: AndroidUsageType.alarm,
      isSpeakerphoneOn: false,
      stayAwake: false,
    ),
  );

  Future<void> _testAlarm() async {
    try {
      await _testPlayer.setAudioContext(_audioCtx);
      await _testPlayer.stop();
      await _testPlayer.play(AssetSource('sounds/alarm.mp3'));
    } catch (_) {}
  }

  Future<void> _testChirp() async {
    try {
      await _testPlayer.setAudioContext(_audioCtx);
      await _testPlayer.stop();
      await _testPlayer.play(AssetSource('sounds/chirp.mp3'));
    } catch (_) {}
  }

  Future<void> _save() async {
    // Capture messenger before async gap (use_build_context_synchronously)
    final messenger = ScaffoldMessenger.of(context);
    await _settingsService.saveConfig(_config);
    if (!mounted) return;
    setState(() => _dirty = false);
    messenger.showSnackBar(
      const SnackBar(
        content: Text('Settings saved'),
        backgroundColor: AppColors.grey,
        duration: Duration(seconds: 2),
      ),
    );
  }

  void _updateConfig(KeywordConfig updated) {
    setState(() {
      _config = updated;
      _dirty = true;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: const Text('SETTINGS'),
        actions: [
          if (_dirty)
            TextButton(
              onPressed: _save,
              child: const Text(
                'SAVE',
                style: TextStyle(
                  color: AppColors.catYellow,
                  fontWeight: FontWeight.bold,
                  letterSpacing: 1,
                ),
              ),
            ),
        ],
      ),
      body: !_loaded
          ? const Center(
              child: CircularProgressIndicator(color: AppColors.catYellow))
          : ListView(
              padding: const EdgeInsets.all(16),
              children: [
                // Safety Keywords
                const _SectionHeader(
                  label: 'SAFETY KEYWORDS',
                  color: AppColors.snaponRed,
                  subtitle: 'Triggers red alert + alarm',
                ),
                _KeywordListEditor(
                  keywords: _config.safetyKeywords,
                  accentColor: AppColors.snaponRed,
                  onChanged: (list) => _updateConfig(
                      _config.copyWith(safetyKeywords: list)),
                ),
                const SizedBox(height: 24),

                // Safety Phrases
                const _SectionHeader(
                  label: 'SAFETY PHRASES',
                  color: AppColors.snaponRed,
                  subtitle: 'Multi-word safety triggers',
                ),
                _KeywordListEditor(
                  keywords: _config.safetyPhrases,
                  accentColor: AppColors.snaponRed,
                  onChanged: (list) => _updateConfig(
                      _config.copyWith(safetyPhrases: list)),
                ),
                const SizedBox(height: 24),

                // Warning Keywords
                const _SectionHeader(
                  label: 'WARNING KEYWORDS',
                  color: AppColors.catYellow,
                  subtitle: 'Triggers yellow alert (pinned)',
                ),
                _KeywordListEditor(
                  keywords: _config.warningKeywords,
                  accentColor: AppColors.catYellow,
                  onChanged: (list) => _updateConfig(
                      _config.copyWith(warningKeywords: list)),
                ),
                const SizedBox(height: 24),

                // Warning Phrases
                const _SectionHeader(
                  label: 'WARNING PHRASES',
                  color: AppColors.catYellow,
                  subtitle: 'Multi-word warning triggers',
                ),
                _KeywordListEditor(
                  keywords: _config.warningPhrases,
                  accentColor: AppColors.catYellow,
                  onChanged: (list) => _updateConfig(
                      _config.copyWith(warningPhrases: list)),
                ),
                const SizedBox(height: 24),

                // Silence Threshold
                const _SectionHeader(
                  label: 'SILENCE THRESHOLD',
                  color: AppColors.greyLight,
                  subtitle: 'Seconds of silence to end a segment',
                ),
                _SliderSetting(
                  value: _config.silenceThresholdMs / 1000.0,
                  min: 1.0,
                  max: 5.0,
                  divisions: 8,
                  label: '${(_config.silenceThresholdMs / 1000.0).toStringAsFixed(1)}s',
                  onChanged: (v) => _updateConfig(
                      _config.copyWith(silenceThresholdMs: (v * 1000).round())),
                ),
                const SizedBox(height: 24),

                // Alert Sounds
                const _SectionHeader(
                  label: 'ALERT SOUNDS',
                  color: AppColors.greyLight,
                  subtitle: 'Audio feedback for keyword detections',
                ),
                Container(
                  decoration: BoxDecoration(
                    color: AppColors.surface,
                    borderRadius: BorderRadius.circular(4),
                    border: Border.all(color: AppColors.grey),
                  ),
                  child: Column(
                    children: [
                      SwitchListTile(
                        value: _config.enableAlarmSound,
                        onChanged: (v) => _updateConfig(
                            _config.copyWith(enableAlarmSound: v)),
                        title: const Text('Alarm sound (red alerts)',
                            style: TextStyle(color: AppColors.textNormal)),
                        subtitle: const Text(
                          'Repeating alarm when safety keywords detected',
                          style:
                              TextStyle(color: AppColors.greyLight, fontSize: 12),
                        ),
                        activeThumbColor: AppColors.snaponRed,
                        tileColor: Colors.transparent,
                      ),
                      const Divider(height: 1, color: AppColors.grey),
                      SwitchListTile(
                        value: _config.enableChirpSound,
                        onChanged: (v) => _updateConfig(
                            _config.copyWith(enableChirpSound: v)),
                        title: const Text('Chirp sound (yellow alerts)',
                            style: TextStyle(color: AppColors.textNormal)),
                        subtitle: const Text(
                          'Brief chirp when warning keywords detected',
                          style:
                              TextStyle(color: AppColors.greyLight, fontSize: 12),
                        ),
                        activeThumbColor: AppColors.catYellow,
                        tileColor: Colors.transparent,
                      ),
                      const Divider(height: 1, color: AppColors.grey),
                      Padding(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 16, vertical: 10),
                        child: Row(
                          children: [
                            const Text(
                              'TEST SOUNDS',
                              style: TextStyle(
                                color: AppColors.greyLight,
                                fontSize: 12,
                                letterSpacing: 1,
                              ),
                            ),
                            const Spacer(),
                            _TestSoundButton(
                              label: 'CHIRP',
                              color: AppColors.catYellow,
                              onTap: _testChirp,
                            ),
                            const SizedBox(width: 10),
                            _TestSoundButton(
                              label: 'ALARM',
                              color: AppColors.snaponRed,
                              onTap: _testAlarm,
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 24),

                // Transcript Log Toggle
                const _SectionHeader(
                  label: 'TRANSCRIPT LOG',
                  color: AppColors.greyLight,
                  subtitle: 'Save text-only session logs (no audio)',
                ),
                SwitchListTile(
                  value: _config.saveTranscriptLog,
                  onChanged: (v) =>
                      _updateConfig(_config.copyWith(saveTranscriptLog: v)),
                  title: const Text('Save transcript logs',
                      style: TextStyle(color: AppColors.textNormal)),
                  subtitle: const Text(
                    'Plain text files saved to app storage',
                    style: TextStyle(color: AppColors.greyLight, fontSize: 12),
                  ),
                  activeThumbColor: AppColors.catYellow,
                  tileColor: AppColors.surface,
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(4)),
                ),
                const SizedBox(height: 32),

                // Reset to defaults
                OutlinedButton(
                  onPressed: () async {
                    await _settingsService.resetToDefaults();
                    await _load();
                    setState(() => _dirty = false);
                  },
                  style: OutlinedButton.styleFrom(
                    foregroundColor: AppColors.greyLight,
                    side: const BorderSide(color: AppColors.grey),
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(4)),
                  ),
                  child: const Text('RESET TO DEFAULTS'),
                ),
                const SizedBox(height: 16),
              ],
            ),
    );
  }
}

class _SectionHeader extends StatelessWidget {
  final String label;
  final Color color;
  final String? subtitle;

  const _SectionHeader(
      {required this.label, required this.color, this.subtitle});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: TextStyle(
              color: color,
              fontSize: 12,
              fontWeight: FontWeight.bold,
              letterSpacing: 2,
            ),
          ),
          if (subtitle != null)
            Text(
              subtitle!,
              style: const TextStyle(
                color: AppColors.greyLight,
                fontSize: 12,
              ),
            ),
        ],
      ),
    );
  }
}

class _KeywordListEditor extends StatefulWidget {
  final List<String> keywords;
  final Color accentColor;
  final ValueChanged<List<String>> onChanged;

  const _KeywordListEditor({
    required this.keywords,
    required this.accentColor,
    required this.onChanged,
  });

  @override
  State<_KeywordListEditor> createState() => _KeywordListEditorState();
}

class _KeywordListEditorState extends State<_KeywordListEditor> {
  final TextEditingController _controller = TextEditingController();

  void _add() {
    final text = _controller.text.trim().toLowerCase();
    if (text.isEmpty || widget.keywords.contains(text)) return;
    widget.onChanged([...widget.keywords, text]);
    _controller.clear();
  }

  void _remove(String keyword) {
    widget.onChanged(widget.keywords.where((k) => k != keyword).toList());
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(4),
        border: Border.all(color: AppColors.grey),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Wrap(
            spacing: 8,
            runSpacing: 6,
            children: widget.keywords
                .map((k) => Chip(
                      label: Text(k,
                          style: const TextStyle(
                              fontSize: 13, color: Colors.black)),
                      backgroundColor: widget.accentColor,
                      deleteIconColor: Colors.black54,
                      onDeleted: () => _remove(k),
                      materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                      padding: const EdgeInsets.symmetric(horizontal: 4),
                    ))
                .toList(),
          ),
          if (widget.keywords.isNotEmpty) const SizedBox(height: 10),
          Row(
            children: [
              Expanded(
                child: TextField(
                  controller: _controller,
                  style: const TextStyle(
                      color: AppColors.textNormal, fontSize: 14),
                  decoration: InputDecoration(
                    hintText: 'Add keyword or phrase...',
                    hintStyle: const TextStyle(
                        color: AppColors.greyLight, fontSize: 13),
                    isDense: true,
                    contentPadding: const EdgeInsets.symmetric(
                        horizontal: 10, vertical: 10),
                    enabledBorder: OutlineInputBorder(
                      borderSide:
                          BorderSide(color: widget.accentColor.withValues(alpha: 0.3)),
                      borderRadius: BorderRadius.circular(4),
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderSide: BorderSide(color: widget.accentColor),
                      borderRadius: BorderRadius.circular(4),
                    ),
                  ),
                  onSubmitted: (_) => _add(),
                ),
              ),
              const SizedBox(width: 8),
              GestureDetector(
                onTap: _add,
                child: Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: widget.accentColor,
                    borderRadius: BorderRadius.circular(4),
                  ),
                  child: const Icon(Icons.add, color: Colors.black, size: 20),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }
}

class _SliderSetting extends StatelessWidget {
  final double value;
  final double min;
  final double max;
  final int divisions;
  final String label;
  final ValueChanged<double> onChanged;

  const _SliderSetting({
    required this.value,
    required this.min,
    required this.max,
    required this.divisions,
    required this.label,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(4),
        border: Border.all(color: AppColors.grey),
      ),
      child: Row(
        children: [
          Expanded(
            child: SliderTheme(
              data: SliderTheme.of(context).copyWith(
                activeTrackColor: AppColors.catYellow,
                thumbColor: AppColors.catYellow,
                inactiveTrackColor: AppColors.grey,
                overlayColor: AppColors.catYellow.withValues(alpha: 0.1),
              ),
              child: Slider(
                value: value,
                min: min,
                max: max,
                divisions: divisions,
                onChanged: onChanged,
              ),
            ),
          ),
          SizedBox(
            width: 40,
            child: Text(
              label,
              style: const TextStyle(
                color: AppColors.catYellow,
                fontWeight: FontWeight.bold,
                fontSize: 14,
              ),
              textAlign: TextAlign.center,
            ),
          ),
        ],
      ),
    );
  }
}

class _TestSoundButton extends StatelessWidget {
  final String label;
  final Color color;
  final VoidCallback onTap;

  const _TestSoundButton({
    required this.label,
    required this.color,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 7),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.12),
          border: Border.all(color: color.withValues(alpha: 0.5)),
          borderRadius: BorderRadius.circular(4),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.play_arrow, color: color, size: 16),
            const SizedBox(width: 4),
            Text(
              label,
              style: TextStyle(
                color: color,
                fontSize: 12,
                fontWeight: FontWeight.bold,
                letterSpacing: 1,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
