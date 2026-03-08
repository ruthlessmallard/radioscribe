import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:permission_handler/permission_handler.dart';

/// Placeholder audio service — wires up mic permission and provides
/// a stream of recognized text segments. Vosk integration hooks in here.
///
/// Current state: simulates STT with a stream for UI development.
/// Replace _simulateRecognition() with real Vosk calls when model is bundled.
class AudioService extends ChangeNotifier {
  bool _isListening = false;
  bool _hasPermission = false;
  String _partialText = '';
  final StreamController<String> _segmentController =
      StreamController<String>.broadcast();

  bool get isListening => _isListening;
  bool get hasPermission => _hasPermission;
  String get partialText => _partialText;

  /// Emits complete segments (after silence detection)
  Stream<String> get segmentStream => _segmentController.stream;

  Future<bool> requestPermission() async {
    final status = await Permission.microphone.request();
    _hasPermission = status.isGranted;
    notifyListeners();
    return _hasPermission;
  }

  Future<void> startListening() async {
    if (!_hasPermission) {
      final granted = await requestPermission();
      if (!granted) return;
    }
    _isListening = true;
    notifyListeners();

    // TODO: Replace with real Vosk STT integration
    // Vosk setup:
    //   1. Load model from assets/models/vosk-model-small-en-us-0.15/
    //   2. Create VoskFlutterPlugin instance
    //   3. Start recognition with silence threshold from settings
    //   4. On partial result: update _partialText
    //   5. On final result (silence detected): push to _segmentController
    _simulateRecognition();
  }

  Future<void> stopListening() async {
    _isListening = false;
    _partialText = '';
    notifyListeners();
  }

  /// Simulation for UI development — remove when Vosk is integrated
  void _simulateRecognition() {
    // No-op in production build — Vosk replaces this
  }

  void _onSegmentComplete(String text, {double confidence = 1.0}) {
    if (text.trim().isNotEmpty) {
      _segmentController.add(text.trim());
    }
    _partialText = '';
    notifyListeners();
  }

  @override
  void dispose() {
    _segmentController.close();
    super.dispose();
  }
}
