class KeywordConfig {
  final List<String> warningKeywords;
  final List<String> safetyKeywords;
  final List<String> warningPhrases;
  final List<String> safetyPhrases;
  final Map<String, List<String>> phoneticAlternates;
  final int silenceThresholdMs;
  final int maxSegmentMs;
  final bool saveTranscriptLog;
  final bool enableAlarmSound;
  final bool enableChirpSound;

  const KeywordConfig({
    this.warningKeywords = const [],
    this.safetyKeywords = const [],
    this.warningPhrases = const [],
    this.safetyPhrases = const [],
    this.phoneticAlternates = const {},
    this.silenceThresholdMs = 2500,
    this.maxSegmentMs = 60000,
    this.saveTranscriptLog = false,
    this.enableAlarmSound = true,
    this.enableChirpSound = true,
  });

  static KeywordConfig get defaults => const KeywordConfig(
        enableAlarmSound: true,
        enableChirpSound: true,

        // ── Safety keywords ─────────────────────────────────────────────────
        // Single words that are unambiguously serious — kept intentionally small
        // to avoid false positives. Prefer phrases where possible.
        safetyKeywords: [
          'mayday',
          'emergency',
          'hazmat',
          'explosion',
          'injured',
          'injury',
          'accident',
          'ambulance',
          'evacuate',
          'evacuation',
          'flood',
          'collapse',
          'trapped',
          'danger',
          'methane',
          'unconscious',
          'unresponsive',
          'rescue',
          'fatality',
          'fatalities',
          'deceased',
          'seismic',
          'rockburst',
          'inundation',
          'fire',
        ],

        // ── Safety phrases ──────────────────────────────────────────────────
        // Phrase-based triggers are far more reliable than single words in noisy
        // environments. These are the primary alarm mechanism.
        safetyPhrases: [
          'fire in the hole',
          'man down',
          'person down',
          'mayday mayday',
          'high wall alert',
          'oxygen low',
          'muster point',
          'exclusion zone',
          'refuge station',
          'safety bypass',
          'clear the bench',
          'radio silence',
          'self rescuer',
          'self-rescuer',
          'lost contact',
          'roof fall',
          'rock fall',
          'gas detected',
          'carbon monoxide',
          'call ambulance',
          'need rescue',
          'code blue',
          'code red',
          'mayday mayday',
          'send help',
          'need medic',
          'structure collapse',
          'fire in',
          'explosion in',
          'people trapped',
          'workers trapped',
          'missing person',
          'missing miner',
          'man down',
          'person down',
        ],

        // ── Warning keywords ────────────────────────────────────────────────
        // Operational issues — chirp alert, no alarm.
        // Removed high-false-positive single words: waiting, problem, issue, pressure.
        warningKeywords: [
          'stoppage',
          'delay',
          'blocked',
          'breakdown',
          'stuck',
          'overheating',
          'leaking',
          'spill',
          'smoke',
          'fumes',
          'dewatering',
          'muddy',
          'unstable',
        ],

        // ── Warning phrases ─────────────────────────────────────────────────
        warningPhrases: [
          'equipment down',
          'machine breakdown',
          'shift delay',
          'low visibility',
          'water ingress',
          'ground movement',
          'ventilation fault',
          'tag out',
          'lock out',
          'gas check',
          'secondary breakage',
          'ground support',
        ],

        // ── Phonetic alternates ─────────────────────────────────────────────
        // Helps catch STT misrecognitions of domain-specific words.
        phoneticAlternates: {
          'stope': ['stop', 'slope'],
          'drift': ['draft', 'rift'],
          'raise': ['raze', 'rays'],
          'muck': ['mak', 'mock'],
          'headframe': ['head frame'],
          'mayday': ['may day', 'mayday'],
          'code blue': ['co blue', 'cold blue', 'code blew'],
          'code red': ['co red', 'cold red', 'code read'],
          'methane': ['me thing', 'me dane'],
          'seismic': ['size mic', 'ses mic'],
          'shotcrete': ['shot crete', 'shot creek'],
          'epiroc': ['epic rock', 'epic roc'],
          'sandvik': ['sand vik', 'sand vic'],
          'winnemucca': ['winnie mucca', 'winna mucca'],
          'turquoise ridge': ['turquoise rich', 'turkey ridge'],
          'leeville': ['lee ville', 'leaville'],
          'goldstrike': ['gold strike'],
          'cortez': ['cor tez', 'court ez'],
          'autoclave': ['auto clave'],
          'grizzly': ['grizly', 'grisly'],
          'def': ['d e f', 'diesel exhaust fluid'],
          'get': ['g e t', 'ground engaging tools'],
        },

        silenceThresholdMs: 2500,
        maxSegmentMs: 60000,
        saveTranscriptLog: false,
      );

  KeywordConfig copyWith({
    List<String>? warningKeywords,
    List<String>? safetyKeywords,
    List<String>? warningPhrases,
    List<String>? safetyPhrases,
    Map<String, List<String>>? phoneticAlternates,
    int? silenceThresholdMs,
    int? maxSegmentMs,
    bool? saveTranscriptLog,
    bool? enableAlarmSound,
    bool? enableChirpSound,
  }) {
    return KeywordConfig(
      warningKeywords: warningKeywords ?? this.warningKeywords,
      safetyKeywords: safetyKeywords ?? this.safetyKeywords,
      warningPhrases: warningPhrases ?? this.warningPhrases,
      safetyPhrases: safetyPhrases ?? this.safetyPhrases,
      phoneticAlternates: phoneticAlternates ?? this.phoneticAlternates,
      silenceThresholdMs: silenceThresholdMs ?? this.silenceThresholdMs,
      maxSegmentMs: maxSegmentMs ?? this.maxSegmentMs,
      saveTranscriptLog: saveTranscriptLog ?? this.saveTranscriptLog,
      enableAlarmSound: enableAlarmSound ?? this.enableAlarmSound,
      enableChirpSound: enableChirpSound ?? this.enableChirpSound,
    );
  }

  Map<String, dynamic> toJson() => {
        'warningKeywords': warningKeywords,
        'safetyKeywords': safetyKeywords,
        'warningPhrases': warningPhrases,
        'safetyPhrases': safetyPhrases,
        'phoneticAlternates': phoneticAlternates,
        'silenceThresholdMs': silenceThresholdMs,
        'maxSegmentMs': maxSegmentMs,
        'saveTranscriptLog': saveTranscriptLog,
        'enableAlarmSound': enableAlarmSound,
        'enableChirpSound': enableChirpSound,
      };

  factory KeywordConfig.fromJson(Map<String, dynamic> json) => KeywordConfig(
        warningKeywords: List<String>.from(json['warningKeywords'] ?? []),
        safetyKeywords: List<String>.from(json['safetyKeywords'] ?? []),
        warningPhrases: List<String>.from(json['warningPhrases'] ?? []),
        safetyPhrases: List<String>.from(json['safetyPhrases'] ?? []),
        phoneticAlternates: (json['phoneticAlternates'] as Map<String, dynamic>?)
                ?.map((k, v) => MapEntry(k, List<String>.from(v))) ??
            {},
        silenceThresholdMs: json['silenceThresholdMs'] ?? 2500,
        maxSegmentMs: json['maxSegmentMs'] ?? 60000,
        saveTranscriptLog: json['saveTranscriptLog'] ?? false,
        enableAlarmSound: json['enableAlarmSound'] ?? true,
        enableChirpSound: json['enableChirpSound'] ?? true,
      );
}
