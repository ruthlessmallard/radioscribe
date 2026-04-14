import 'package:flutter/material.dart';
import '../theme/app_theme.dart';

enum SegmentAlert { none, warning, safety }

class TranscriptSegment {
  final String id;
  final String text;
  final DateTime timestamp;
  final SegmentAlert alert;
  final List<String> matchedKeywords;
  final double confidence;
  bool isDismissed;

  /// Raw transcription before LLM correction
  final String? rawText;

  /// List of corrections applied (for debugging/display)
  final List<String> corrections;

  TranscriptSegment({
    required this.id,
    required this.text,
    required this.timestamp,
    this.alert = SegmentAlert.none,
    this.matchedKeywords = const [],
    this.confidence = 1.0,
    this.isDismissed = false,
    this.rawText,
    this.corrections = const [],
  });

  bool get isPinned => alert != SegmentAlert.none && !isDismissed;
  bool get isSafety => alert == SegmentAlert.safety;
  bool get isWarning => alert == SegmentAlert.warning;

  Color get backgroundColor {
    switch (alert) {
      case SegmentAlert.safety:
        return AppColors.snaponRed.withValues(alpha: 0.15);
      case SegmentAlert.warning:
        return AppColors.catYellow.withValues(alpha: 0.12);
      case SegmentAlert.none:
        return Colors.transparent;
    }
  }

  Color get borderColor {
    switch (alert) {
      case SegmentAlert.safety:
        return AppColors.snaponRed;
      case SegmentAlert.warning:
        return AppColors.catYellow;
      case SegmentAlert.none:
        return Colors.transparent;
    }
  }

  Color get textColor {
    switch (alert) {
      case SegmentAlert.safety:
        return Colors.white;
      case SegmentAlert.warning:
        return Colors.white;
      case SegmentAlert.none:
        return confidence < 0.6
            ? AppColors.textFaded
            : AppColors.textNormal;
    }
  }

  TranscriptSegment copyWith({
    bool? isDismissed,
    String? text,
    String? rawText,
    List<String>? corrections,
    SegmentAlert? alert,
    List<String>? matchedKeywords,
  }) {
    return TranscriptSegment(
      id: id,
      text: text ?? this.text,
      timestamp: timestamp,
      alert: alert ?? this.alert,
      matchedKeywords: matchedKeywords ?? this.matchedKeywords,
      confidence: confidence,
      isDismissed: isDismissed ?? this.isDismissed,
      rawText: rawText ?? this.rawText,
      corrections: corrections ?? this.corrections,
    );
  }
}
