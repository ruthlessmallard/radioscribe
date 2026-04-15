import 'dart:async';
import 'dart:math' as math;
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
///
/// Audio preprocessing: 300-3400Hz bandpass filter to match radio frequency range.
class AudioService extends ChangeNotifier {
  // ── Public state ──────────────────────────────────────────────────────────
  bool _isListening = false;
  bool _hasPermission = false;
  String _partialText = '';
  bool _modelLoaded = false;
  bool _modelError = false;
  String _modelErrorMessage = '';

  bool get isListening => _isListening;
  bool get hasPermission => _hasPermission;
  String get partialText => _partialText;
  bool get modelLoaded => _modelLoaded;
  bool get modelError => _modelError;
  String get modelErrorMessage => _modelErrorMessage;

  /// Emits completed transcript segments (after endpoint or max-duration flush).
  Stream<String> get segmentStream => _segmentController.stream;

  // ── Configuration ─────────────────────────────────────────────────────────
  static const int _sampleRate = 16000;
  static const Duration _maxSegmentDuration = Duration(seconds: 60);

  // Bandpass filter constants embedded in _applyBandpassFilter

  // Energy gate threshold (RMS amplitude below this = silence/noise)
  // Tuned for 16kHz PCM normalized to [-1.0, 1.0]
  // INCREASED: was 0.015 - too aggressive, caused gibberish
  static const double _energyGateThreshold = 0.008;
  static const int _minConsecutiveSilentFrames = 5; // ~100ms at typical chunk sizes

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

  // Bandpass filter state (biquad cascade: high-pass @ 300Hz, low-pass @ 3400Hz)
  double _hpX1 = 0, _hpX2 = 0, _hpY1 = 0, _hpY2 = 0;
  double _lpX1 = 0, _lpX2 = 0, _lpY1 = 0, _lpY2 = 0;

  // Energy gate state
  int _consecutiveSilentFrames = 0;

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

  /// Returns true if the bundled model asset has real content (not a placeholder).
  Future<bool> _modelAssetsPresent() async {
    try {
      final data = await rootBundle.load('assets/models/encoder.onnx');
      return data.lengthInBytes > 1024; // real encoder is tens of MB
    } catch (_) {
      return false;
    }
  }

  Future<void> _ensureModelLoaded() async {
    if (_modelLoaded || _modelError) return;
    try {
      // Guard against empty placeholder files — sherpa_onnx C++ will hard-crash
      // if fed a 0-byte ONNX file, which can't be caught in Dart.
      if (!await _modelAssetsPresent()) {
        debugPrint('[AudioService] Model assets are placeholders — STT unavailable.');
        _modelError = true;
        notifyListeners();
        return;
      }

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

      // NOTE: hotwords context biasing disabled - causes init failure in 1.12.36
      // Post-processing via LlmCorrectionService handles mining term correction
      // TODO: Re-enable after Sherpa ONNX hotwords stabilizes

      final config = sherpa_onnx.OnlineRecognizerConfig(
        model: sherpa_onnx.OnlineModelConfig(
          transducer: sherpa_onnx.OnlineTransducerModelConfig(
            encoder: encoderPath,
            decoder: decoderPath,
            joiner: joinerPath,
          ),
          tokens: tokensPath,
          numThreads: 2,
          debug: true,
          modelType: '',
        ),
        enableEndpoint: true,
        // Tuned for noisy mine environment: cut off faster in silence
        rule1MinTrailingSilence: 0.8, // Was 2.4 - end quickly after speech
        rule2MinTrailingSilence: 0.4, // Was 1.2 - tighter for noise bursts
        rule3MinUtteranceLength: 20.0,
        decodingMethod: 'greedy_search',
        maxActivePaths: 4,
        blankPenalty: 1.5, // Penalize blanks to reduce hallucinations on noise
      );

      _recognizer = sherpa_onnx.OnlineRecognizer(config);
      _onlineStream = _recognizer!.createStream();

      _modelLoaded = true;
      debugPrint('[AudioService] sherpa_onnx model loaded successfully.');
    } catch (e, st) {
      debugPrint('[AudioService] Model load failed: $e\n$st');
      _modelError = true;
      _modelErrorMessage = e.toString();
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
      var samplesFloat32 = _convertBytesToFloat32(data);
      // Apply 300-3400Hz bandpass filter before STT
      samplesFloat32 = _applyBandpassFilter(samplesFloat32);

      // NOTE: Energy gate disabled - was causing gibberish by zeroing speech frames
      // Bandpass filter provides sufficient noise reduction
      // _consecutiveSilentFrames logic preserved but unused

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
    // Use offset-aware ByteData view — stream chunks may have non-zero offsetInBytes
    final values = Float32List(bytes.lengthInBytes ~/ 2);
    final data = ByteData.view(
        bytes.buffer, bytes.offsetInBytes, bytes.lengthInBytes);
    for (var i = 0; i < bytes.lengthInBytes; i += 2) {
      final short = data.getInt16(i, endian);
      values[i ~/ 2] = short / 32768.0;
    }
    return values;
  }

  // ── Bandpass filter (300-3400Hz) ───────────────────────────────────────────

  /// Apply 2nd-order Butterworth bandpass filter (cascade of HP @ 300Hz + LP @ 3400Hz).
  /// Tuned for 16kHz sample rate to match typical radio voice range.
  Float32List _applyBandpassFilter(Float32List samples) {
    // Coefficients pre-calculated for Butterworth @ 16kHz
    // High-pass @ 300Hz (2nd order)
    const double hpB0 = 0.9706196;
    const double hpB1 = -1.9412393;
    const double hpB2 = 0.9706196;
    const double hpA1 = -1.9409320;
    const double hpA2 = 0.9415465;

    // Low-pass @ 3400Hz (2nd order)
    const double lpB0 = 0.2075319;
    const double lpB1 = 0.4150638;
    const double lpB2 = 0.2075319;
    const double lpA1 = -0.3139590;
    const double lpA2 = 0.1440860;

    final output = Float32List(samples.length);

    for (var i = 0; i < samples.length; i++) {
      final x = samples[i];

      // High-pass stage
      final hpOut = hpB0 * x + hpB1 * _hpX1 + hpB2 * _hpX2 - hpA1 * _hpY1 - hpA2 * _hpY2;
      _hpX2 = _hpX1;
      _hpX1 = x;
      _hpY2 = _hpY1;
      _hpY1 = hpOut;

      // Low-pass stage
      final lpOut = lpB0 * hpOut + lpB1 * _lpX1 + lpB2 * _lpX2 - lpA1 * _lpY1 - lpA2 * _lpY2;
      _lpX2 = _lpX1;
      _lpX1 = hpOut;
      _lpY2 = _lpY1;
      _lpY1 = lpOut;

      output[i] = lpOut;
    }

    return output;
  }

  /// Check if frame energy (RMS) is below threshold indicating silence/noise.
  bool _isEnergyBelowThreshold(Float32List samples) {
    if (samples.isEmpty) return true;
    double sumSquares = 0.0;
    for (final s in samples) {
      sumSquares += s * s;
    }
    final rms = math.sqrt(sumSquares / samples.length);
    return rms < _energyGateThreshold;
  }

  // ── Dispose ───────────────────────────────────────────────────────────────

  @override
  void dispose() {
    _maxSegmentTimer?.cancel();
    _audioSub?.cancel();
    _recorder?.stop().catchError((_) => null);
    _onlineStream?.free();
    _recognizer?.free();
    _segmentController.close();
    super.dispose();
  }
}
