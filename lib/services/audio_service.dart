import 'dart:async';
import 'dart:typed_data';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:record/record.dart';
import 'package:path_provider/path_provider.dart';
import 'package:path/path.dart' as p;
import 'package:sherpa_onnx/sherpa_onnx.dart' as sherpa_onnx;
import 'package:wakelock_plus/wakelock_plus.dart';
import 'dart:io';

/// AudioService — wraps sherpa_onnx offline STT with the record package.
///
/// Lifecycle:
///   1. On first [startListening], loads the sherpa_onnx model from assets
///      (extracts to app support dir, cached after first load).
///   2. Streams mic audio (PCM 16-bit, 16kHz, mono) through the recognizer.
///   3. Partial results update [partialText] and call notifyListeners().
///   4. Endpoint detection or 60s max triggers a segment flush →
///      emitted on [segmentStream].
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

  /// Emits completed transcript segments (after endpoint or max-duration flush).
  Stream<String> get segmentStream => _segmentController.stream;

  // ── Configuration ─────────────────────────────────────────────────────────
  static const int _sampleRate = 16000;
  static const Duration _maxSegmentDuration = Duration(seconds: 60);

  // ── Internals ─────────────────────────────────────────────────────────────
  final StreamController<String> _segmentController =
      StreamController<String>.broadcast();

  // sherpa_onnx objects (cached after first load)
  sherpa_onnx.OnlineRecognizer? _recognizer;
  sherpa_onnx.OnlineStream? _onlineStream;

  // Record package
  AudioRecorder? _recorder;
  StreamSubscription<Uint8List>? _audioSub;

  // Timers
  Timer? _maxSegmentTimer;

  // ── Permission ────────────────────────────────────────────────────────────

  Future<bool> requestPermission() async {
    final status = await Permission.microphone.request();
    _hasPermission = status.isGranted;
    notifyListeners();
    return _hasPermission;
  }

  // ── Model loading ─────────────────────────────────────────────────────────

  Future<String> _copyAssetFile(String assetPath, String filename) async {
    final directory = await getApplicationSupportDirectory();
    final target = p.join(directory.path, filename);
    final data = await rootBundle.load(assetPath);
    final exists = await File(target).exists();
    if (!exists || File(target).lengthSync() != data.lengthInBytes) {
      final bytes =
          data.buffer.asUint8List(data.offsetInBytes, data.lengthInBytes);
      await File(target).writeAsBytes(bytes);
    }
    return target;
  }

  Future<void> _ensureModelLoaded() async {
    if (_modelLoaded || _modelError) return;
    try {
      debugPrint('[AudioService] Initializing sherpa_onnx bindings...');
      sherpa_onnx.initBindings();

      debugPrint('[AudioService] Extracting model files from assets...');
      final encoderPath = await _copyAssetFile(
          'assets/models/encoder.onnx', 'encoder.onnx');
      final decoderPath = await _copyAssetFile(
          'assets/models/decoder.onnx', 'decoder.onnx');
      final joinerPath = await _copyAssetFile(
          'assets/models/joiner.onnx', 'joiner.onnx');
      final tokensPath = await _copyAssetFile(
          'assets/models/tokens.txt', 'tokens.txt');

      debugPrint('[AudioService] Creating OnlineRecognizer...');
      final config = sherpa_onnx.OnlineRecognizerConfig(
        model: sherpa_onnx.OnlineModelConfig(
          zipformer2: sherpa_onnx.OnlineZipformer2TransducerModelConfig(
            encoder: encoderPath,
            decoder: decoderPath,
            joiner: joinerPath,
          ),
          tokens: tokensPath,
          numThreads: 2,
          debug: false,
        ),
        enableEndpoint: true,
        rule1MinTrailingSilence: 2.4,
        rule2MinTrailingSilence: 1.2,
        rule3MinUtteranceLength: 20.0,
        decodingMethod: 'greedy_search',
        maxActivePaths: 4,
      );

      _recognizer = sherpa_onnx.OnlineRecognizer(config);
      _onlineStream = _recognizer!.createStream();

      _modelLoaded = true;
      debugPrint('[AudioService] sherpa_onnx model loaded successfully.');
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
    _maxSegmentTimer?.cancel();
    _maxSegmentTimer = null;

    await _audioSub?.cancel();
    _audioSub = null;

    try {
      await _recorder?.stop();
    } catch (_) {}
    _recorder = null;

    // Flush any remaining recognition
    if (_recognizer != null && _onlineStream != null) {
      final text = _recognizer!.getResult(_onlineStream!).text.trim();
      if (text.isNotEmpty) {
        _segmentController.add(text);
      }
      // Free old stream and create a fresh one for next session
      _onlineStream!.free();
      _onlineStream = _recognizer!.createStream();
    }

    _partialText = '';
    notifyListeners();

    try {
      await WakelockPlus.disable();
    } catch (_) {}
  }

  // ── Audio processing ──────────────────────────────────────────────────────

  void _onAudioChunk(Uint8List data) {
    if (_recognizer == null || _onlineStream == null) return;

    try {
      final samplesFloat32 =
          _convertBytesToFloat32(data);
      _onlineStream!.acceptWaveform(
          samples: samplesFloat32, sampleRate: _sampleRate);

      while (_recognizer!.isReady(_onlineStream!)) {
        _recognizer!.decode(_onlineStream!);
      }

      final text = _recognizer!.getResult(_onlineStream!).text.trim();

      if (_recognizer!.isEndpoint(_onlineStream!)) {
        // Endpoint detected — emit segment and reset stream
        if (text.isNotEmpty) {
          _segmentController.add(text);
        }
        _recognizer!.reset(_onlineStream!);
        _partialText = '';
        _resetMaxSegmentTimer();
        notifyListeners();
      } else if (text != _partialText) {
        _partialText = text;
        notifyListeners();
      }
    } catch (e) {
      debugPrint('[AudioService] Recognizer error: $e');
    }
  }

  // ── Max-segment timer ─────────────────────────────────────────────────────

  void _onMaxSegmentTimeout() {
    debugPrint('[AudioService] Max segment duration reached — flushing.');
    if (_recognizer != null && _onlineStream != null) {
      final text = _recognizer!.getResult(_onlineStream!).text.trim();
      if (text.isNotEmpty) {
        _segmentController.add(text);
      }
      _recognizer!.reset(_onlineStream!);
      _partialText = '';
      notifyListeners();
    }
    _resetMaxSegmentTimer();
  }

  void _resetMaxSegmentTimer() {
    _maxSegmentTimer?.cancel();
    _maxSegmentTimer = Timer(_maxSegmentDuration, _onMaxSegmentTimeout);
  }

  // ── PCM helpers ───────────────────────────────────────────────────────────

  Float32List _convertBytesToFloat32(Uint8List bytes,
      [Endian endian = Endian.little]) {
    final values = Float32List(bytes.length ~/ 2);
    final data = ByteData.view(bytes.buffer);
    for (var i = 0; i < bytes.length; i += 2) {
      final short = data.getInt16(i, endian);
      values[i ~/ 2] = short / 32768.0;
    }
    return values;
  }

  // ── Dispose ───────────────────────────────────────────────────────────────

  @override
  void dispose() {
    _maxSegmentTimer?.cancel();
    _audioSub?.cancel();
    _recorder?.stop().catchError((_) {});
    _onlineStream?.free();
    _recognizer?.free();
    _segmentController.close();
    super.dispose();
  }
}
