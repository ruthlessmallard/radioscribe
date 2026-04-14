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
  final bool debugMode;

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
    this.debugMode = false,
  });

  static KeywordConfig get defaults => const KeywordConfig(
        enableAlarmSound: true,
        enableChirpSound: true,
        warningKeywords: [
          'stoppage',
          'delay',
          'blocked',
          'waiting',
          'breakdown',
          'stuck',
          'problem',
          'issue',
          'overheating',
          'leaking',
          'spill',
          'smoke',
          'fumes',
          'pressure',
          'dewatering',
          'muddy',
          'unstable',
        ],
        safetyKeywords: [
          'emergency',
          'fire',
          'explosion',
          'injured',
          'injury',
          'accident',
          'ambulance',
          'evacuate',
          'evacuation',
          'gas',
          'flood',
          'collapse',
          'trapped',
          'mayday',
          'help',
          'danger',
          'hazard',
          'blasting',
          'blast',
          'methane',
          'oxygen',
          'unconscious',
          'unresponsive',
          'rescue',
          'fatality',
          'fatalities',
          'deceased',
          'seismic',
          'rockburst',
          'inundation',
        ],
        warningPhrases: [
          'equipment down',
          'machine breakdown',
          'shift delay',
          'low visibility',
          'water ingress',
          'ground movement',
          'ventilation fault',
        ],
        safetyPhrases: [
          'man down',
          'person down',
          'lost contact',
          'power outage',
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
        ],
        phoneticAlternates: {
          'stope': ['stop', 'slope'],
          'drift': ['draft', 'rift'],
          'raise': ['raze', 'rays'],
          'muck': ['mak', 'mock'],
          'headframe': ['head frame'],
          'blasting': ['blasting', 'lasting'],
          'mayday': ['may day', 'mayday'],
          'code blue': ['co blue', 'cold blue', 'code blew'],
          'code red': ['co red', 'cold red', 'code read'],
          'methane': ['me thing', 'me dane'],
          'seismic': ['size mic', 'ses mic'],
        },
        silenceThresholdMs: 2500,
        maxSegmentMs: 60000,
        saveTranscriptLog: false,
        debugMode: false,
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
    bool? debugMode,
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
      debugMode: debugMode ?? this.debugMode,
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
        'debugMode': debugMode,
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
        debugMode: json['debugMode'] ?? false,
      );
}
