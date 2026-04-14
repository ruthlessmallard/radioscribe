/// LLM Correction Service — post-processes Sherpa output with mining context.
///
/// Uses a lightweight rule-based approach suitable for on-device operation.
/// For heavier correction, integrate an ONNX runtime LLM.
///
/// Maintains rolling context (3-4 segments) to resolve ambiguous words
/// based on surrounding conversation.

import 'dart:collection';
import 'mining_vocabulary.dart';

class LlmCorrectionService {
  /// Maximum segments to keep in rolling context
  static const int maxContextSegments = 4;

  /// Minimum confidence threshold for corrections
  static const double correctionThreshold = 0.7;

  /// Rolling buffer of recent segments for context awareness
  final Queue<String> _contextBuffer = Queue<String>();

  /// Corrections applied in last segment (for debugging/telemetry)
  final List<Correction> lastCorrections = [];

  /// Process a new segment with context-aware correction.
  ///
  /// Returns corrected text. Updates internal context buffer.
  String correct(String rawSegment) {
    lastCorrections.clear();

    // Step 1: Apply basic phonetic/term corrections
    var corrected = MiningVocabulary.applyBasicCorrection(rawSegment);

    // Step 2: Context-aware disambiguation
    corrected = _applyContextDisambiguation(corrected);

    // Step 3: Mining term validation
    corrected = _validateMiningTerms(corrected);

    // Update rolling context
    _updateContext(corrected);

    return corrected;
  }

  /// Get current context as a single string.
  String getContextString() {
    return _contextBuffer.join(' | ');
  }

  /// Clear the context buffer.
  void clearContext() {
    _contextBuffer.clear();
    lastCorrections.clear();
  }

  /// Update context buffer with new segment.
  void _updateContext(String segment) {
    _contextBuffer.addLast(segment);
    while (_contextBuffer.length > maxContextSegments) {
      _contextBuffer.removeFirst();
    }
  }

  /// Apply context-aware disambiguation.
  ///
  /// Uses surrounding context to resolve ambiguous terms.
  /// Example: "the jumbo is drilling" → confirms "jumbo" not "jumble"
  String _applyContextDisambiguation(String text) {
    final context = getContextString().toLowerCase();
    var result = text;

    // Context clues that strengthen mining term likelihood
    final miningContextClues = [
      'drill', 'blast', 'muck', 'haul', 'stope', 'drift', 'shaft',
      'mine', 'mining', 'underground', 'ore', 'shift', 'equipment',
    ];

    // Check if we're in a mining context
    final bool inMiningContext = miningContextClues.any(
      (clue) => context.contains(clue) || text.toLowerCase().contains(clue),
    );

    if (inMiningContext) {
      // Boost mining terms over generic words when ambiguous
      result = _boostMiningTerms(result);
    }

    return result;
  }

  /// Boost mining-specific terms when acoustically similar to common words.
  String _boostMiningTerms(String text) {
    // Common confusions in mining context
    final Map<String, String> contextualBoosts = {
      // Only apply if surrounding context suggests mining
      'jumble': 'jumbo',
      'bolted': 'bolter',
      'stop': 'stope',  // Already in basic correction, but boost in context
      'draft': 'drift',
    };

    var result = text;
    contextualBoosts.forEach((common, mining) {
      // More aggressive replacement in mining context
      final pattern = RegExp(r'\b' + RegExp.escape(common) + r'\b', caseSensitive: false);
      if (pattern.hasMatch(result)) {
        result = result.replaceAll(pattern, mining);
        lastCorrections.add(Correction(
          original: common,
          corrected: mining,
          reason: 'contextual_boost',
          confidence: 0.75,
        ));
      }
    });

    return result;
  }

  /// Validate and fix mining terms that don't make sense.
  String _validateMiningTerms(String text) {
    // Fix common nonsensical combinations
    final Map<String, String> nonsensicalFixes = {
      'stope drilling': 'stope',  // "stope" is the location, not the action
      'drift blasting': 'drift',  // clarify location vs action
    };

    var result = text;
    nonsensicalFixes.forEach((nonsense, fix) {
      result = result.replaceAll(nonsense, fix);
    });

    return result;
  }

  /// Check if a segment contains negated safety keywords.
  /// Returns true if the segment should NOT trigger a safety alert.
  bool isNegatedSafetyAlert(String text) {
    final lower = text.toLowerCase();

    // Check for negation patterns with safety keywords
    final safetyKeywords = [
      'fire', 'emergency', 'evacuation', 'injured', 'injury',
      'accident', 'gas', 'methane', 'collapse', 'trapped',
    ];

    for (final keyword in safetyKeywords) {
      if (MiningVocabulary.containsNegation(text, keyword)) {
        return true;
      }
    }

    // Explicit all-clear phrases
    final allClearPhrases = [
      'all clear',
      'false alarm',
      'drill complete',
      'test complete',
      'stand down',
    ];

    return allClearPhrases.any((phrase) => lower.contains(phrase));
  }

  /// Get confidence score for a correction.
  /// Higher = more confident the correction is valid.
  double getCorrectionConfidence(String original, String corrected) {
    // Exact match in vocabulary = high confidence
    if (MiningVocabulary.hotwords.containsKey(corrected.toLowerCase())) {
      return 0.9;
    }

    // In common errors map = medium-high confidence
    if (MiningVocabulary.commonErrors.containsKey(original.toLowerCase())) {
      return 0.8;
    }

    // Context-based = medium confidence
    return 0.6;
  }
}

/// Represents a single correction for debugging/telemetry.
class Correction {
  final String original;
  final String corrected;
  final String reason;
  final double confidence;

  Correction({
    required this.original,
    required this.corrected,
    required this.reason,
    required this.confidence,
  });

  @override
  String toString() =>
      'Correction($original → $corrected, $reason, ${(confidence * 100).toStringAsFixed(0)}%)';
}
