import 'dart:async';
import 'package:flutter/material.dart';
import 'package:audioplayers/audioplayers.dart';
import '../models/segment.dart';
import '../models/keyword_config.dart';
import '../services/keyword_service.dart';
import '../services/settings_service.dart';
import '../services/audio_service.dart';
import '../services/transcript_log_service.dart';
import '../theme/app_theme.dart';
import '../widgets/segment_card.dart';

class ListenScreen extends StatefulWidget {
  const ListenScreen({super.key});

  @override
  State<ListenScreen> createState() => _ListenScreenState();
}

class _ListenScreenState extends State<ListenScreen> {
  final AudioService _audioService = AudioService();
  final TranscriptLogService _logService = TranscriptLogService();
  final AudioPlayer _alarmPlayer = AudioPlayer();
  late KeywordService _keywordService;
  late SettingsService _settingsService;

  final List<TranscriptSegment> _pinnedSegments = [];
  final List<TranscriptSegment> _scrollingSegments = [];
  static const int _maxScrollingSegments = 40;

  Timer? _alarmTimer;
  bool _alarmActive = false;
  bool _isInitialized = false;

  StreamSubscription<String>? _segmentSub;

  @override
  void initState() {
    super.initState();
    _init();
  }

  Future<void> _init() async {
    _settingsService = await SettingsService.getInstance();
    _keywordService = KeywordService(_settingsService.config);

    if (_settingsService.config.saveTranscriptLog) {
      await _logService.startSession();
    }

    _segmentSub = _audioService.segmentStream.listen(_onSegment);

    setState(() => _isInitialized = true);
  }

  void _onSegment(String text) {
    final result = _keywordService.analyze(text);
    final segment = TranscriptSegment(
      id: DateTime.now().microsecondsSinceEpoch.toString(),
      text: text,
      timestamp: DateTime.now(),
      alert: result.alert,
      matchedKeywords: result.matched,
    );

    if (_settingsService.config.saveTranscriptLog) {
      _logService.logSegment(segment);
    }

    setState(() {
      if (segment.isPinned) {
        if (segment.isSafety) {
          _pinnedSegments.insert(0, segment);
          _triggerSafetyAlarm();
        } else {
          // Insert after safety segments
          final insertIdx = _pinnedSegments
              .indexWhere((s) => !s.isSafety);
          if (insertIdx == -1) {
            _pinnedSegments.add(segment);
          } else {
            _pinnedSegments.insert(insertIdx, segment);
          }
        }
      } else {
        _scrollingSegments.add(segment);
        if (_scrollingSegments.length > _maxScrollingSegments) {
          _scrollingSegments.removeAt(0);
        }
      }
    });
  }

  void _triggerSafetyAlarm() {
    if (_alarmActive) return;
    _alarmActive = true;
    // 20-second delay before first alarm
    Future.delayed(const Duration(seconds: 20), () {
      if (!mounted || !_alarmActive) return;
      _playAlarm();
      _alarmTimer = Timer.periodic(const Duration(seconds: 20), (_) {
        if (_alarmActive) _playAlarm();
      });
    });
  }

  Future<void> _playAlarm() async {
    try {
      await _alarmPlayer.play(AssetSource('sounds/alarm.mp3'));
    } catch (_) {
      // Alarm sound not yet bundled — no-op
    }
  }

  void _dismissSegment(TranscriptSegment segment) {
    setState(() {
      final idx = _pinnedSegments.indexWhere((s) => s.id == segment.id);
      if (idx != -1) {
        _pinnedSegments.removeAt(idx);
      }
      // Stop alarm if no more safety segments
      if (!_pinnedSegments.any((s) => s.isSafety)) {
        _alarmActive = false;
        _alarmTimer?.cancel();
        _alarmTimer = null;
      }
    });
  }

  Future<void> _toggleListening() async {
    if (_audioService.isListening) {
      await _audioService.stopListening();
    } else {
      await _audioService.startListening();
    }
    setState(() {});
  }

  @override
  void dispose() {
    _segmentSub?.cancel();
    _alarmTimer?.cancel();
    _alarmPlayer.dispose();
    _audioService.stopListening();
    _logService.endSession();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: Row(
          children: [
            const Text('RADIOSCRIBE'),
            const SizedBox(width: 12),
            if (_audioService.isListening)
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: AppColors.snaponRed.withValues(alpha: 0.15),
                  border: Border.all(color: AppColors.snaponRed, width: 1),
                  borderRadius: BorderRadius.circular(2),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Container(
                      width: 6,
                      height: 6,
                      decoration: const BoxDecoration(
                        color: AppColors.snaponRed,
                        shape: BoxShape.circle,
                      ),
                    ),
                    const SizedBox(width: 5),
                    const Text(
                      'LIVE',
                      style: TextStyle(
                        color: AppColors.snaponRed,
                        fontSize: 11,
                        fontWeight: FontWeight.bold,
                        letterSpacing: 1.5,
                      ),
                    ),
                  ],
                ),
              ),
          ],
        ),
        actions: [
          IconButton(
            icon: Icon(
              _audioService.isListening ? Icons.mic_off : Icons.mic,
              color: _audioService.isListening
                  ? AppColors.snaponRed
                  : AppColors.catYellow,
            ),
            onPressed: _toggleListening,
            tooltip: _audioService.isListening ? 'Stop' : 'Start',
          ),
        ],
      ),
      body: !_isInitialized
          ? const Center(
              child: CircularProgressIndicator(color: AppColors.catYellow))
          : Column(
              children: [
                // Pinned segments (safety on top, warnings below)
                if (_pinnedSegments.isNotEmpty)
                  Container(
                    color: AppColors.surface,
                    child: Column(
                      children: [
                        ..._pinnedSegments.map((seg) => SegmentCard(
                              segment: seg,
                              onDismiss: () => _dismissSegment(seg),
                              showTimestamp: true,
                            )),
                        Container(height: 1, color: AppColors.grey),
                      ],
                    ),
                  ),
                // Scrolling transcript
                Expanded(
                  child: ListView.builder(
                    reverse: true,
                    padding: const EdgeInsets.symmetric(
                        horizontal: 12, vertical: 8),
                    itemCount: _scrollingSegments.length +
                        (_audioService.partialText.isNotEmpty ? 1 : 0),
                    itemBuilder: (context, index) {
                      // Partial (in-progress) text at top (index 0 = most recent)
                      if (index == 0 &&
                          _audioService.partialText.isNotEmpty) {
                        return Padding(
                          padding: const EdgeInsets.symmetric(
                              vertical: 3, horizontal: 14),
                          child: Text(
                            _audioService.partialText,
                            style: const TextStyle(
                              color: AppColors.textFaded,
                              fontSize: 16,
                              fontStyle: FontStyle.italic,
                            ),
                          ),
                        );
                      }
                      final segIndex = _scrollingSegments.length -
                          1 -
                          (index -
                              (_audioService.partialText.isNotEmpty ? 1 : 0));
                      if (segIndex < 0) return const SizedBox.shrink();
                      return SegmentCard(
                        segment: _scrollingSegments[segIndex],
                        onDismiss: () {},
                        showTimestamp: false,
                      );
                    },
                  ),
                ),
                // Bottom bar — rebuilds whenever AudioService notifies
                ListenableBuilder(
                  listenable: _audioService,
                  builder: (context, _) {
                    String statusText;
                    if (_audioService.modelError) {
                      statusText = 'STT error: ${_audioService.modelErrorMessage}';
                    } else if (_audioService.isListening &&
                        !_audioService.modelLoaded) {
                      statusText = 'Loading speech model...';
                    } else if (_audioService.isListening) {
                      statusText = 'Monitoring radio traffic...';
                    } else {
                      statusText = 'Tap mic to start monitoring';
                    }

                    final bottomInset = MediaQuery.of(context).padding.bottom;
                    return Container(
                      color: AppColors.surface,
                      padding: EdgeInsets.fromLTRB(
                          20, 14, 20, 14 + bottomInset),
                      child: Row(
                        children: [
                          Expanded(
                            child: Text(
                              statusText,
                              style: TextStyle(
                                color: _audioService.modelError
                                    ? AppColors.snaponRed
                                    : AppColors.greyLight,
                                fontSize: 13,
                              ),
                            ),
                          ),
                          GestureDetector(
                            onTap: _audioService.modelError
                                ? null
                                : _toggleListening,
                            child: Container(
                              padding: const EdgeInsets.all(16),
                              decoration: BoxDecoration(
                                shape: BoxShape.circle,
                                color: _audioService.modelError
                                    ? AppColors.grey
                                    : (_audioService.isListening
                                        ? AppColors.snaponRed
                                        : AppColors.catYellow),
                              ),
                              child: Icon(
                                _audioService.isListening
                                    ? Icons.mic_off
                                    : Icons.mic,
                                color: Colors.black,
                                size: 28,
                              ),
                            ),
                          ),
                        ],
                      ),
                    );
                  },
                ),
              ],
            ),
    );
  }
}
