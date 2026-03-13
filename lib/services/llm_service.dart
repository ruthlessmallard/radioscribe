import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:flutter_gemma/flutter_gemma.dart';
import 'package:path_provider/path_provider.dart';
import 'package:path/path.dart' as p;

/// LlmService — on-device Gemma post-processing for Sherpa transcript segments.
///
/// Uses flutter_gemma (MediaPipe / LiteRT) to clean up garbled STT output in
/// the context of mine radio communications. Operates fully offline.
///
/// Model file: gemma-2b-it-gpu-int4.bin (~1.5 GB), .task, or similar.
/// User imports the file via Settings → AI Correction → Import Model.
///
/// Usage:
///   1. Call [loadModel] after the user imports the model file.
///   2. Call [correct] with each raw Sherpa segment.
///   3. Rolling context is maintained in the prompt (not in Gemma's session).
class LlmService extends ChangeNotifier {
  LlmService._();
  static final LlmService instance = LlmService._();

  // ── Public state ──────────────────────────────────────────────────────────
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

  // ── Config ────────────────────────────────────────────────────────────────
  static const _modelFilename = 'gemma-radioscribe.bin';
  static const _maxContextLines = 3;
  static const _maxTokens = 256;
  // Recreate the chat session every N corrections to prevent context overflow.
  static const _sessionRefreshEvery = 8;

  // ── State ─────────────────────────────────────────────────────────────────
  InferenceModel? _model;
  InferenceChat? _chat;
  int _correctionCount = 0;
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

  /// Import a model file from [sourcePath] (e.g. from the Downloads folder).
  /// Copies it to app support dir, then loads it.
  Future<bool> importModel(String sourcePath) async {
    try {
      final dest = await modelPath;
      debugPrint('[LlmService] Copying model: $sourcePath → $dest');
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

  /// Install and initialise the Gemma model from app support dir.
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

      debugPrint('[LlmService] Registering model with flutter_gemma...');

      // Detect file type from extension — .task/.litertlm = task, else binary.
      final fileType = (path.endsWith('.task') || path.endsWith('.litertlm'))
          ? ModelFileType.task
          : ModelFileType.binary;

      // Register/install the model so flutter_gemma knows about it.
      await FlutterGemma.installModel(
        modelType: ModelType.gemmaIt,
        fileType: fileType,
      ).fromFile(path).install();

      // Create the inference model instance.
      _model = await FlutterGemmaPlugin.instance.createModel(
        modelType: ModelType.gemmaIt,
        fileType: fileType,
        maxTokens: _maxTokens,
      );

      // Pre-warm the first chat session.
      await _refreshChat();

      _modelLoaded = true;
      _modelLoading = false;
      debugPrint('[LlmService] Gemma model ready.');
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

  Future<void> _refreshChat() async {
    try {
      await _chat?.session.close();
    } catch (_) {}
    _chat = await _model!.createChat(
      temperature: 0.1,
      topK: 1,
      randomSeed: 42,
    );
    _correctionCount = 0;
  }

  void setEnabled(bool value) {
    _enabled = value;
    notifyListeners();
  }

  // ── Correction ────────────────────────────────────────────────────────────

  /// Post-process a raw Sherpa segment. Returns the corrected text.
  /// Falls back to [rawText] if the model isn't loaded or returns garbage.
  Future<String> correct(String rawText) async {
    if (!enabled || _model == null || _chat == null) return rawText;

    try {
      // Refresh session periodically to avoid context overflow.
      if (_correctionCount >= _sessionRefreshEvery) {
        await _refreshChat();
      }

      final prompt = _buildPrompt(rawText);
      await _chat!.addQueryChunk(Message(text: prompt, isUser: true));
      final response = await _chat!.session.getResponse();

      _correctionCount++;
      _addToContext(rawText);

      return _clean(response, rawText);
    } catch (e) {
      debugPrint('[LlmService] Correction error: $e');
      _addToContext(rawText);
      // Try refreshing on next call after an error.
      _correctionCount = _sessionRefreshEvery;
      return rawText;
    }
  }

  // ── Helpers ───────────────────────────────────────────────────────────────

  String _buildPrompt(String rawText) {
    final ctx = _contextLines.isNotEmpty
        ? _contextLines.join('\n')
        : '(no prior context)';

    return 'Fix obvious speech recognition errors in this mine radio '
        'transmission from northern Nevada. Reply with ONLY the corrected '
        'text — no explanation.\n'
        'Context:\n$ctx\n'
        'Raw: $rawText\n'
        'Corrected:';
  }

  /// Strip noise from the model response and sanity-check it.
  String _clean(String response, String fallback) {
    final cleaned = response
        .replaceAll(RegExp(r'<[^>]+>'), '')
        .replaceAll(RegExp(r'\s+'), ' ')
        .trim();

    if (cleaned.isEmpty) return fallback;
    if (cleaned.length > fallback.length * 3) return fallback;
    if (cleaned.toLowerCase().contains('as an ai')) return fallback;

    return cleaned.toUpperCase();
  }

  void _addToContext(String text) {
    _contextLines.add(text);
    if (_contextLines.length > _maxContextLines) {
      _contextLines.removeAt(0);
    }
  }

  /// Clear context and refresh the chat session (call at session end).
  Future<void> clearContext() async {
    _contextLines.clear();
    if (_model != null) await _refreshChat();
  }
}
