import '../models/keyword_config.dart';
import '../models/segment.dart';
import 'profanity_service.dart';

class KeywordService {
  final KeywordConfig config;

  KeywordService(this.config);

  /// Analyze a text segment and return its alert level + matched keywords.
  /// Profanity is censored in the returned [text] before display.
  ({SegmentAlert alert, List<String> matched, String text}) analyze(
      String text) {
    // Censor profanity before display — do this first so the censored version
    // is what gets stored in the transcript log.
    final cleanText = ProfanityService.censor(text);

    final lower = cleanText.toLowerCase();
    final matched = <String>[];

    // Expand text with phonetic alternates before matching
    final expanded = _expandWithAlternates(lower);

    // Check safety phrases first (highest priority)
    for (final phrase in config.safetyPhrases) {
      if (expanded.contains(phrase.toLowerCase())) {
        matched.add(phrase);
        return (
          alert: SegmentAlert.safety,
          matched: matched,
          text: cleanText,
        );
      }
    }

    // Check safety keywords
    for (final keyword in config.safetyKeywords) {
      if (_containsWord(expanded, keyword.toLowerCase())) {
        matched.add(keyword);
        return (
          alert: SegmentAlert.safety,
          matched: matched,
          text: cleanText,
        );
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
      return (alert: SegmentAlert.warning, matched: matched, text: cleanText);
    }

    return (alert: SegmentAlert.none, matched: [], text: cleanText);
  }

  /// Expand text by adding phonetic alternate forms
  String _expandWithAlternates(String text) {
    var expanded = text;
    config.phoneticAlternates.forEach((canonical, alternates) {
      for (final alt in alternates) {
        if (text.contains(alt.toLowerCase())) {
          expanded = '$expanded $canonical';
          break;
        }
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
