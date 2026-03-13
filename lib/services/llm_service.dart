import 'dart:async';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:flutter_gemma/flutter_gemma.dart';
import 'package:path_provider/path_provider.dart';
import 'package:path/path.dart' as p;

/// LlmService — on-device LLM post-processing for Sherpa transcript segments.
///
/// Uses Gemma 2B-IT via MediaPipe (flutter_gemma) to clean up garbled
/// speech-recognition output in the context of mine radio communications.
///
/// Model file: gemma-2b-it-gpu-int4.bin (~1.5 GB)
/// Must be imported by the user via Settings → AI Correction → Import Model.
///
/// Usage:
///   1. Call [loadModel] after the user imports the model file.
///   2. Call [correct] with each raw Sherpa segment.
///   3. Rolling context is maintained automatically.
class LlmService extends ChangeNotifier {
  LlmService._();
  static final LlmService instance = LlmService._();

  // ── Public state ────────────────────────────────────────────────────────
  bool _modelLoaded = false;
  bool _modelLoading = false;
  bool _modelError = false;
  String _modelErrorMessage = '';
  bool _enabled = false;

  bool get modelLoaded => _modelLoaded;
  bool get modelLoading => _modelLoading;
  bool get modelError => _modelError;
  String get modelErrorMessage => _modelErrorMessage;
  bool get enabled => _enabled && _modelLoaded;

  // ── Config ───────────────────────────────────────────────────────────────
  static const _modelFilename = 'gemma-2b-it-gpu-int4.bin';
  static const _maxContextLines = 3;
  static const _maxResponseTokens = 128;

  // ── State ────────────────────────────────────────────────────────────────
  final List<String> _contextLines = [];

  // ── Model file path ───────────────────────────────────────────────────────

  Future<String> get modelPath async {
    final dir = await getApplicationSupportDirectory();
    return p.join(dir.path, _modelFilename);
  }

  Future<bool> get isModelPresent async {
    final path = await modelPath;
    return File(path).existsSync();
  }

  // ── Model management ──────────────────────────────────────────────────────

  /// Import a model file from [sourcePath] (e.g. picked from Downloads).
  /// Copies it to app support dir, then loads it.
  Future<bool> importModel(String sourcePath) async {
    try {
      final dest = await modelPath;
      debugPrint('[LlmService] Copying model from $sourcePath → $dest');
      await File(sourcePath).copy(dest);
      return await loadModel();
    } catch (e) {
      debugPrint('[LlmService] Import failed: $e');
      _modelError = true;
      _modelErrorMessage = e.toString();
      notifyListeners();
      return false;
    }
  }

  /// Load the Gemma model from app support dir into MediaPipe.
  Future<bool> loadModel() async {
    if (_modelLoaded) return true;
    if (_modelLoading) return false;

    _modelLoading = true;
    _modelError = false;
    _modelErrorMessage = '';
    notifyListeners();

    try {
      final path = await modelPath;
      if (!File(path).existsSync()) {
        throw Exception('Model file not found at $path');
      }

      debugPrint('[LlmService] Loading Gemma model...');
      await FlutterGemmaPlugin.instance.init(
        modelPath: path,
        maxTokens: _maxResponseTokens,
        temperature: 0.1,  // Low temp — we want deterministic corrections
        topK: 1,
        randomSeed: 42,
      );

      _modelLoaded = true;
      _modelLoading = false;
      debugPrint('[LlmService] Gemma model loaded.');
      notifyListeners();
      return true;
    } catch (e, st) {
      debugPrint('[LlmService] Load failed: $e\n$st');
      _modelLoaded = false;
      _modelLoading = false;
      _modelError = true;
      _modelErrorMessage = e.toString();
      notifyListeners();
      return false;
    }
  }

  void setEnabled(bool value) {
    _enabled = value;
    notifyListeners();
  }

  // ── Correction ────────────────────────────────────────────────────────────

  /// Post-process a raw Sherpa segment. Returns the corrected text.
  /// Falls back to [rawText] if the model isn't loaded or returns garbage.
  Future<String> correct(String rawText) async {
    if (!enabled) return rawText;

    try {
      final prompt = _buildPrompt(rawText);
      final response =
          await FlutterGemmaPlugin.instance.getResponse(prompt: prompt);
      final corrected = _clean(response, rawText);

      // Update rolling context with the raw input (not the correction, so
      // the model keeps seeing realistic mine radio language in context).
      _addToContext(rawText);

      return corrected;
    } catch (e) {
      debugPrint('[LlmService] Correction error: $e');
      _addToContext(rawText);
      return rawText;
    }
  }

  // ── Helpers ───────────────────────────────────────────────────────────────

  String _buildPrompt(String rawText) {
    final ctx = _contextLines.isNotEmpty
        ? _contextLines.join('\n')
        : '(no prior context)';

    return '''<start_of_turn>user
You are a transcription corrector for mine radio communications in northern Nevada. Fix obvious speech recognition errors using mining vocabulary and radio protocol context. Keep the same meaning and length. Reply with ONLY the corrected text — no explanation, no quotes.

Previous transmissions:
$ctx

Raw transcription: $rawText<end_of_turn>
<start_of_turn>model
''';
  }

  /// Sanitize the model's response — strip extra whitespace, reject outputs
  /// that look hallucinated (too long, or contain nothing useful).
  String _clean(String response, String fallback) {
    final cleaned = response
        .replaceAll(RegExp(r'<[^>]+>'), '') // strip any stray tags
        .replaceAll(RegExp(r'\s+'), ' ')
        .trim();

    // Sanity checks — fall back to raw if response is suspicious
    if (cleaned.isEmpty) return fallback;
    if (cleaned.length > rawTextMaxLength(fallback) * 3) return fallback;
    if (cleaned.toLowerCase().contains('as an ai')) return fallback;

    return cleaned.toUpperCase(); // match existing all-caps transcript style
  }

  int rawTextMaxLength(String text) => text.length.clamp(10, 500);

  void _addToContext(String text) {
    _contextLines.add(text);
    if (_contextLines.length > _maxContextLines) {
      _contextLines.removeAt(0);
    }
  }

  /// Clear rolling context (e.g. at session end).
  void clearContext() {
    _contextLines.clear();
  }
}
