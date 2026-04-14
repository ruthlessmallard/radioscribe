import '../models/keyword_config.dart';
import '../models/segment.dart';
import 'mining_vocabulary.dart';
import 'llm_correction_service.dart';

class KeywordService {
  final KeywordConfig config;
  final LlmCorrectionService _corrector = LlmCorrectionService();

  KeywordService(this.config);

  /// Analyze a text segment and return its alert level + matched keywords.
  /// Applies LLM correction with rolling context before keyword matching.
  ({SegmentAlert alert, List<String> matched, String correctedText}) analyze(String text) {
    // Apply context-aware correction
    final corrected = _corrector.correct(text);
    final lower = corrected.toLowerCase();
    final matched = <String>[];

    // Expand text with phonetic alternates before matching
    final expanded = _expandWithAlternates(lower);

    // Check for negated safety alerts (e.g., "no fire", "not injured")
    if (_corrector.isNegatedSafetyAlert(corrected)) {
      // Return warning level for negated alerts (still worth noting, but not safety)
      return (alert: SegmentAlert.none, matched: [], correctedText: corrected);
    }

    // Check safety phrases first (highest priority)
    for (final phrase in config.safetyPhrases) {
      if (expanded.contains(phrase.toLowerCase())) {
        matched.add(phrase);
        return (alert: SegmentAlert.safety, matched: matched, correctedText: corrected);
      }
    }

    // Check safety keywords
    for (final keyword in config.safetyKeywords) {
      if (_containsWord(expanded, keyword.toLowerCase())) {
        matched.add(keyword);
        return (alert: SegmentAlert.safety, matched: matched, correctedText: corrected);
      }
    }

    // Check warning phrases
    for (final phrase in config.warningPhrases) {
      if (expanded.contains(phrase.toLowerCase())) {
        matched.add(phrase);
      }
    }

    // Check warning keywords
    for (final keyword in config.warningKeywords) {
      if (_containsWord(expanded, keyword.toLowerCase())) {
        matched.add(keyword);
      }
    }

    if (matched.isNotEmpty) {
      return (alert: SegmentAlert.warning, matched: matched, correctedText: corrected);
    }

    return (alert: SegmentAlert.none, matched: [], correctedText: corrected);
  }

  /// Get the last LLM corrections applied (for debugging UI)
  List<Correction> get lastCorrections => _corrector.lastCorrections;

  /// Get current rolling context string
  String get contextString => _corrector.getContextString();

  /// Clear the correction context
  void clearContext() => _corrector.clearContext();

  /// Expand text by adding phonetic alternate forms.
  /// Also includes mining vocabulary hotwords for fuzzy matching.
  String _expandWithAlternates(String text) {
    var expanded = text;

    // User-configured alternates
    config.phoneticAlternates.forEach((canonical, alternates) {
      for (final alt in alternates) {
        if (text.contains(alt.toLowerCase())) {
          expanded = '$expanded $canonical';
          break;
        }
      }
    });

    // Mining vocabulary alternates (from common errors map)
    MiningVocabulary.commonErrors.forEach((error, canonical) {
      if (text.contains(error.toLowerCase())) {
        expanded = '$expanded $canonical';
      }
    });

    return expanded;
  }

  /// Check if text contains a word (not just substring)
  bool _containsWord(String text, String word) {
    final pattern = RegExp(r'\b' + RegExp.escape(word) + r'\b');
    return pattern.hasMatch(text);
  }
}
