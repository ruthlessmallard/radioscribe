import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';
import 'package:flutter/foundation.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:record/record.dart';
import 'package:vosk_flutter/vosk_flutter.dart';
import 'package:wakelock_plus/wakelock_plus.dart';

/// AudioService — wraps Vosk offline STT with the record package.
///
/// Lifecycle:
///   1. On first [startListening], loads the Vosk model from assets (cached).
///   2. Streams mic audio (PCM 16-bit, 16kHz, mono) through the recognizer.
///   3. Partial results update [partialText] and call notifyListeners().
///   4. Silence > [silenceThresholdSeconds] (default 3s) or 60s max triggers
///      a final-result flush → emitted on [segmentStream].
///   5. [stopListening] flushes any remaining text and stops the recorder.
class AudioService extends ChangeNotifier {
  // ── Public state ──────────────────────────────────────────────────────────
  bool _isListening = false;
  bool _hasPermission = false;
  String _partialText = '';
  bool _modelLoaded = false;
  bool _modelError = false;

  bool get isListening => _isListening;
  bool get hasPermission => _hasPermission;
  String get partialText => _partialText;
  bool get modelLoaded => _modelLoaded;
  bool get modelError => _modelError;

  /// Emits completed transcript segments (after silence or max-duration flush).
  Stream<String> get segmentStream => _segmentController.stream;

  // ── Configuration ─────────────────────────────────────────────────────────
  static const String _modelAssetPath =
      'assets/models/vosk-model-small-en-us-0.15';
  static const int _sampleRate = 16000;
  static const double _silenceThresholdSeconds = 3.0;
  static const Duration _maxSegmentDuration = Duration(seconds: 60);

  // ── Internals ─────────────────────────────────────────────────────────────
  final StreamController<String> _segmentController =
      StreamController<String>.broadcast();

  // Vosk objects (cached after first load)
  Model? _model;
  Recognizer? _recognizer;

  // Record package
  AudioRecorder? _recorder;
  StreamSubscription<Uint8List>? _audioSub;

  // Timers
  Timer? _silenceTimer;
  Timer? _maxSegmentTimer;

  // ── Permission ────────────────────────────────────────────────────────────

  Future<bool> requestPermission() async {
    final status = await Permission.microphone.request();
    _hasPermission = status.isGranted;
    notifyListeners();
    return _hasPermission;
  }

  // ── Model loading ─────────────────────────────────────────────────────────

  Future<void> _ensureModelLoaded() async {
    if (_modelLoaded || _modelError) return;
    try {
      debugPrint('[AudioService] Loading Vosk model from assets...');
      final modelPath =
          await ModelLoader().loadFromAssets(_modelAssetPath);
      _model = await VoskFlutterPlugin.instance().createModel(modelPath);
      _recognizer = await VoskFlutterPlugin.instance()
          .createRecognizer(model: _model!, sampleRate: _sampleRate.toDouble());
      _modelLoaded = true;
      debugPrint('[AudioService] Vosk model loaded.');
    } catch (e, st) {
      debugPrint('[AudioService] Model load failed: $e\n$st');
      _modelError = true;
    }
    notifyListeners();
  }

  // ── Listening lifecycle ───────────────────────────────────────────────────

  Future<void> startListening() async {
    if (_isListening) return;

    if (!_hasPermission) {
      final granted = await requestPermission();
      if (!granted) return;
    }

    await _ensureModelLoaded();
    if (_modelError) {
      debugPrint('[AudioService] Cannot start: model failed to load.');
      return;
    }

    _recorder = AudioRecorder();

    try {
      final audioStream = await _recorder!.startStream(
        const RecordConfig(
          encoder: AudioEncoder.pcm16bits,
          sampleRate: _sampleRate,
          numChannels: 1,
        ),
      );

      _isListening = true;
      notifyListeners();

      // Prevent screen sleep while monitoring
      try {
        await WakelockPlus.enable();
      } catch (_) {}

      // Start max-segment timer
      _maxSegmentTimer = Timer(_maxSegmentDuration, _onMaxSegmentTimeout);

      // Subscribe to audio chunks
      _audioSub = audioStream.listen(
        _onAudioChunk,
        onError: (Object e) {
          debugPrint('[AudioService] Audio stream error: $e');
        },
        cancelOnError: false,
      );
    } catch (e) {
      debugPrint('[AudioService] Failed to start recorder: $e');
      _recorder = null;
    }
  }

  Future<void> stopListening() async {
    if (!_isListening) return;

    _isListening = false;
    _silenceTimer?.cancel();
    _silenceTimer = null;
    _maxSegmentTimer?.cancel();
    _maxSegmentTimer = null;

    await _audioSub?.cancel();
    _audioSub = null;

    try {
      await _recorder?.stop();
    } catch (_) {}
    _recorder = null;

    // Flush any remaining recognition
    await _flushFinalResult();

    _partialText = '';
    notifyListeners();

    try {
      await WakelockPlus.disable();
    } catch (_) {}
  }

  // ── Audio processing ──────────────────────────────────────────────────────

  Future<void> _onAudioChunk(Uint8List data) async {
    if (_recognizer == null) return;

    try {
      final isFinal = await _recognizer!.acceptWaveformBytes(data);

      if (isFinal) {
        // Recognizer detected an end-of-utterance
        final json = await _recognizer!.getResult();
        final text = _parseTextField(json, 'text');
        _emitSegment(text);
        _cancelSilenceTimer();
      } else {
        // Partial result available
        final json = await _recognizer!.getPartialResult();
        final partial = _parseTextField(json, 'partial');
        if (partial != _partialText) {
          _partialText = partial;
          notifyListeners();
          if (partial.isNotEmpty) {
            _resetSilenceTimer();
          }
        }
      }
    } catch (e) {
      debugPrint('[AudioService] Recognizer error: $e');
    }
  }

  // ── Silence / max-segment timers ──────────────────────────────────────────

  void _resetSilenceTimer() {
    _silenceTimer?.cancel();
    _silenceTimer = Timer(
      Duration(milliseconds: (_silenceThresholdSeconds * 1000).round()),
      _onSilenceTimeout,
    );
  }

  void _cancelSilenceTimer() {
    _silenceTimer?.cancel();
    _silenceTimer = null;
  }

  Future<void> _onSilenceTimeout() async {
    debugPrint('[AudioService] Silence threshold reached — flushing.');
    await _flushFinalResult();
    _resetMaxSegmentTimer();
  }

  Future<void> _onMaxSegmentTimeout() async {
    debugPrint('[AudioService] Max segment duration reached — flushing.');
    await _flushFinalResult();
    _resetMaxSegmentTimer();
  }

  void _resetMaxSegmentTimer() {
    _maxSegmentTimer?.cancel();
    _maxSegmentTimer = Timer(_maxSegmentDuration, _onMaxSegmentTimeout);
  }

  // ── Result helpers ────────────────────────────────────────────────────────

  Future<void> _flushFinalResult() async {
    if (_recognizer == null) return;
    try {
      final json = await _recognizer!.getFinalResult();
      final text = _parseTextField(json, 'text');
      _emitSegment(text);
    } catch (e) {
      debugPrint('[AudioService] getFinalResult error: $e');
    }
  }

  void _emitSegment(String text) {
    final trimmed = text.trim();
    if (trimmed.isNotEmpty) {
      _segmentController.add(trimmed);
    }
    _partialText = '';
    notifyListeners();
  }

  String _parseTextField(String jsonStr, String field) {
    try {
      final map = jsonDecode(jsonStr) as Map<String, dynamic>;
      return (map[field] as String? ?? '').trim();
    } catch (_) {
      return '';
    }
  }

  // ── Dispose ───────────────────────────────────────────────────────────────

  @override
  void dispose() {
    _silenceTimer?.cancel();
    _maxSegmentTimer?.cancel();
    _audioSub?.cancel();
    _recorder?.stop().catchError((_) {});
    _segmentController.close();
    super.dispose();
  }
}
