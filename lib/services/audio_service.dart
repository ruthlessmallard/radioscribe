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
///   2. Streams mic audio (PCM 16-bit, 16kHz, mono) through a 300–3400 Hz
///      bandpass filter, then amplitude-gated, then fed to the recognizer.
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

  /// RMS amplitude gate — chunks quieter than this are replaced with silence
  /// before reaching the recognizer, preventing hallucinations from engine
  /// rumble and background noise.
  ///
  /// 0.02 ≈ −34 dBFS. Keyboard clicks and ambient room noise typically sit
  /// below this; sustained speech is well above it.
  static const double _rmsGateThreshold = 0.02;

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

  // Bandpass filter state (persists across audio chunks)
  _BiquadFilter? _bandpassFilter;

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
      return data.lengthInBytes > 1024;
    } catch (_) {
      return false;
    }
  }

  /// Write the mining hotwords file to app support dir and return the path.
  /// One phrase per line — sherpa_onnx uses these to boost domain vocab during
  /// beam search decoding.
  Future<String> _writeHotwordsFile() async {
    final directory = await getApplicationSupportDirectory();
    final path = p.join(directory.path, 'hotwords.txt');
    await File(path).writeAsString(_hotwordsContent);
    return path;
  }

  Future<void> _ensureModelLoaded() async {
    if (_modelLoaded || _modelError) return;
    try {
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
      final hotwordsPath = await _writeHotwordsFile();

      debugPrint('[AudioService] Creating OnlineRecognizer...');
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
        // rule1: endpoint after longer silence (normal radio pause)
        rule1MinTrailingSilence: 2.4,
        // rule2: tightened — faster endpoint on short transmissions
        rule2MinTrailingSilence: 0.8,
        rule3MinUtteranceLength: 20.0,
        decodingMethod: 'modified_beam_search',
        // Reduced from 8 → 4 to limit hallucination paths in noise
        maxActivePaths: 4,
        hotwordsFile: hotwordsPath,
        // Boost score: 2.0 gives strong domain vocabulary preference
        hotwordsScore: 2.0,
      );

      _recognizer = sherpa_onnx.OnlineRecognizer(config);
      _onlineStream = _recognizer!.createStream();

      // Initialize the bandpass filter (300–3400 Hz at 16 kHz)
      _bandpassFilter = _BiquadFilter.bandpass300to3400();

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

      try {
        await WakelockPlus.enable();
      } catch (_) {}

      _maxSegmentTimer = Timer(_maxSegmentDuration, _onMaxSegmentTimeout);

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

    if (_recognizer != null && _onlineStream != null) {
      final text = _recognizer!.getResult(_onlineStream!).text.trim();
      if (text.isNotEmpty) {
        _segmentController.add(text);
      }
      _onlineStream!.free();
      _onlineStream = _recognizer!.createStream();
    }

    // Reset filter state between sessions
    _bandpassFilter?.reset();

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
      var samples = _convertBytesToFloat32(data);

      // 1. Bandpass filter: keep 300–3400 Hz, attenuate engine rumble and hiss.
      if (_bandpassFilter != null) {
        samples = _bandpassFilter!.process(samples);
      }

      // 2. Amplitude gate: if the chunk is too quiet, feed silence to the
      //    recognizer instead of noise. Prevents hallucinations from near-silent
      //    passages.
      if (_rms(samples) < _rmsGateThreshold) {
        samples = Float32List(samples.length); // all zeros
      }

      _onlineStream!.acceptWaveform(
          samples: samples, sampleRate: _sampleRate);

      while (_recognizer!.isReady(_onlineStream!)) {
        _recognizer!.decode(_onlineStream!);
      }

      final text = _recognizer!.getResult(_onlineStream!).text.trim();

      if (_recognizer!.isEndpoint(_onlineStream!)) {
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
    final values = Float32List(bytes.lengthInBytes ~/ 2);
    final data = ByteData.view(
        bytes.buffer, bytes.offsetInBytes, bytes.lengthInBytes);
    for (var i = 0; i < bytes.lengthInBytes; i += 2) {
      final short = data.getInt16(i, endian);
      values[i ~/ 2] = short / 32768.0;
    }
    return values;
  }

  /// Root mean square of a float sample buffer.
  double _rms(Float32List samples) {
    if (samples.isEmpty) return 0.0;
    double sum = 0.0;
    for (final s in samples) {
      sum += s * s;
    }
    return math.sqrt(sum / samples.length);
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

// ─────────────────────────────────────────────────────────────────────────────
// _BiquadFilter — Direct Form II second-order IIR section.
//
// Coefficients for a 300–3400 Hz Butterworth bandpass at Fs = 16 kHz,
// derived via the Audio EQ Cookbook (constant 0 dB peak gain):
//
//   f0  = sqrt(300 × 3400) ≈ 1010 Hz   (geometric centre)
//   BW  = 3400 − 300 = 3100 Hz
//   Q   = f0 / BW ≈ 0.3258
//   ω0  = 2π × 1010 / 16000 ≈ 0.3969 rad
//   α   = sin(ω0) / (2Q) ≈ 0.5942
//
//   b0 =  α / (1 + α) ≈  0.3727
//   b1 =  0
//   b2 = −α / (1 + α) ≈ −0.3727
//   a1 = −2·cos(ω0) / (1 + α) ≈ −1.1568
//   a2 =  (1 − α) / (1 + α) ≈  0.2546
//
// The passband is intentionally broad — the goal is to cut rumble (<300 Hz)
// and hiss (>3400 Hz), not to act as a tight notch filter.
// ─────────────────────────────────────────────────────────────────────────────
class _BiquadFilter {
  final double b0, b1, b2;
  final double a1, a2;

  double _x1 = 0.0, _x2 = 0.0; // input delay line
  double _y1 = 0.0, _y2 = 0.0; // output delay line

  _BiquadFilter({
    required this.b0,
    required this.b1,
    required this.b2,
    required this.a1,
    required this.a2,
  });

  factory _BiquadFilter.bandpass300to3400() {
    return _BiquadFilter(
      b0:  0.37270,
      b1:  0.0,
      b2: -0.37270,
      a1: -1.15680,
      a2:  0.25460,
    );
  }

  /// Process a block of samples in-place and return the filtered buffer.
  Float32List process(Float32List input) {
    final out = Float32List(input.length);
    for (var i = 0; i < input.length; i++) {
      final x = input[i];
      final y = b0 * x + b1 * _x1 + b2 * _x2 - a1 * _y1 - a2 * _y2;
      _x2 = _x1;
      _x1 = x;
      _y2 = _y1;
      _y1 = y;
      out[i] = y;
    }
    return out;
  }

  /// Clear delay line state between sessions.
  void reset() {
    _x1 = _x2 = _y1 = _y2 = 0.0;
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Mining hotwords — written to disk at startup and passed to the recognizer.
// One phrase per line. sherpa_onnx uses these during modified_beam_search to
// boost the probability of domain-specific vocabulary.
// ─────────────────────────────────────────────────────────────────────────────
const String _hotwordsContent = '''
mayday
emergency
fire in the hole
man down
tag out
lock out
clear the bench
radio silence
high wall alert
oxygen low
gas check
muster point
all clear
exclusion zone
scaling
shoring
mandoor
self-rescuer
refuge station
safety bypass
hazmat
muck pile
muck
mucker
face drill
long hole
shotcrete
shooter
ground support
head frame
vent bag
secondary breakage
leach pad
barren solution
heap leach
carbon in column
refractory ore
autoclave
stope
drift
rib
back
face
bench
grizzly
crusher
conveyor
tailings
slurry
adit
decline
portal
sump
sump pump
stockpile
haul road
scaling bar
ore body
waste dump
caterpillar
komatsu
sandvik
epiroc
joy global
hitachi
liebherr
kubota
boart longyear
dyno nobel
orica
atlas copco
finning
western states
shifter
nipper
grader
greaser
powderman
potlicker
widowmaker
slusher
tramming
bogging
checking the brass
hot change
muck out
barring down
round out
drill out
copy
affirmative
negative
say again
break break
going hot
radio check
wilco
standby
elko
winnemucca
battle mountain
carlin
lovelock
fallon
wells
ely
turquoise ridge
cortez
goldstrike
phoenix
round mountain
twin creeks
long canyon
meikle
pipeline
deep south
rodeo
leeville
multimeter
amp clamp
impact wrench
torque multiplier
hydraulic jack
grease gun
dial indicator
feeler gauges
bore gauge
caliper
micrometer
ohm meter
load bank
cutting torch
stick welder
hydraulic hose
o-ring
jic fitting
orfs
bulkhead
seal kit
filter element
v-belt
serpentine belt
snap ring
cotter pin
bushings
bearings
wear plate
hydraulic oil
final drive oil
differential fluid
coolant
antifreeze
ether
brake cleaner
degreaser
penetrating oil
urea
def
grease cert
sample bottle
articulating joint
transmission
differential
final drive
wheel motor
hydraulic cylinder
turbocharger
aftercooler
injector
fuel rail
alternator
starter motor
accumulator
main pump
swing motor
undercarriage
track link
grouser bar
''';
