/// Mining vocabulary for Sherpa hotwords boosting and LLM context correction.
///
/// Terms are weighted by importance — higher scores = more likely to be
/// recognized when acoustically ambiguous.
///
/// Source: Common underground mining terminology, equipment names, and
/// safety protocols used in hard rock and coal mining operations.
library;

class MiningVocabulary {
  /// Hotwords with boost scores for Sherpa context biasing.
  /// Score range: typically 1.0-10.0 (higher = stronger bias)
  static const Map<String, double> hotwords = {
    // Equipment and machinery
    'jumbo': 8.0,
    'bolter': 8.0,
    'scooptram': 8.0,
    'scoop': 6.0,
    'tram': 6.0,
    'mucker': 7.0,
    'muck': 7.0,
    'LHD': 8.0,
    'loader': 6.0,
    'haul truck': 7.0,
    'dump truck': 6.0,
    'excavator': 6.0,
    'drill': 6.0,
    'longhole': 8.0,
    'stoper': 8.0,
    'jackleg': 8.0,
    'sinker': 7.0,
    'raise climber': 8.0,
    'alimak': 8.0,
    'manlift': 7.0,
    'cage': 6.0,
    'skip': 6.0,
    'hoist': 7.0,
    'headframe': 8.0,
    'shaft': 7.0,
    'winze': 8.0,
    'raise': 7.0,
    'stope': 8.0,
    'drift': 7.0,
    'crosscut': 7.0,
    'decline': 7.0,
    'ramp': 6.0,
    'adit': 7.0,
    'portal': 6.0,
    'sublevel': 7.0,
    'ore pass': 7.0,
    'waste pass': 7.0,
    'chute': 6.0,
    'grizzly': 7.0,
    'rockbreaker': 7.0,
    'crusher': 6.0,
    'conveyor': 6.0,
    'belt': 5.0,
    'vent bag': 7.0,
    'ventilation': 6.0,
    'fan': 5.0,
    'compressor': 6.0,
    'booster': 6.0,
    'transformer': 6.0,
    'substation': 6.0,
    'switchgear': 6.0,
    'cap lamp': 7.0,
    'self-rescuer': 8.0,
    'SCSR': 8.0,
    'dräger': 7.0,
    'gas monitor': 7.0,
    'anemometer': 7.0,
    'blast meter': 7.0,

    // Mining operations and methods
    'drilling': 6.0,
    'blasting': 7.0,
    'mucking': 7.0,
    'haulage': 6.0,
    'backfill': 7.0,
    'paste fill': 7.0,
    'cemented': 6.0,
    'hydraulic': 6.0,
    'cut and fill': 7.0,
    'room and pillar': 7.0,
    'longhole stoping': 8.0,
    'shrinkage': 7.0,
    'sublevel stoping': 8.0,
    'block caving': 7.0,
    'panel caving': 7.0,
    'open stope': 7.0,
    'underhand': 7.0,
    'overhand': 7.0,
    'breast': 6.0,
    'resue': 7.0,
    'square set': 7.0,
    'timbering': 6.0,
    'bolting': 6.0,
    'mesh': 5.0,
    'shotcrete': 7.0,
    'crete': 6.0,
    'ground support': 7.0,
    'rehab': 6.0,

    // Geology and ground conditions
    'ore': 6.0,
    'waste': 5.0,
    'vein': 6.0,
    'lode': 6.0,
    'seam': 6.0,
    'reef': 6.0,
    'dyke': 6.0,
    'fault': 6.0,
    'shear': 6.0,
    'foliation': 7.0,
    'joint': 6.0,
    'fracture': 6.0,
    'competent': 7.0,
    'incompetent': 7.0,
    'slickenside': 8.0,
    'gouge': 7.0,
    'water bearing': 7.0,
    'aquifer': 7.0,
    'dewatering': 7.0,
    'sump': 6.0,
    'pump': 5.0,
    'borehole': 6.0,
    'piezometer': 8.0,

    // Hazards and safety
    'methane': 9.0,
    'CH4': 9.0,
    'firedamp': 8.0,
    'blackdamp': 8.0,
    'afterdamp': 8.0,
    'stinkdamp': 8.0,
    'CO': 8.0,
    'carbon monoxide': 9.0,
    'CO2': 7.0,
    'H2S': 9.0,
    'hydrogen sulfide': 9.0,
    'SO2': 8.0,
    'NO2': 8.0,
    'radon': 8.0,
    'silica': 7.0,
    'quartz': 6.0,
    'respirable': 7.0,
    'dust': 5.0,
    'spontaneous combustion': 9.0,
    'outburst': 8.0,
    'bump': 7.0,
    'rockburst': 8.0,
    'seismic': 7.0,
    'event': 5.0,
    'tremor': 6.0,
    'subsidence': 7.0,
    'crown': 6.0,
    'pillar': 6.0,
    'rib': 5.0,
    'back': 5.0,
    'hanging wall': 7.0,
    'footwall': 7.0,
    'slough': 7.0,
    'ravelling': 7.0,
    'scaling': 6.0,
    'barring': 6.0,
    'loose': 5.0,
    'drawbell': 7.0,
    'hangup': 7.0,
    'bridging': 6.0,
    'rat holing': 7.0,
    'mud rush': 8.0,
    'water inrush': 8.0,
    'inundation': 8.0,

    // Personnel and roles
    'miner': 6.0,
    'shift boss': 7.0,
    'mine captain': 7.0,
    'foreman': 6.0,
    'supervisor': 6.0,
    'engineer': 6.0,
    'geologist': 7.0,
    'surveyor': 7.0,
    'sampling': 6.0,
    'assay': 6.0,
    'tagger': 6.0,
    'nipper': 7.0,
    'mucker operator': 7.0,
    'driller': 6.0,
    'blaster': 7.0,
    'powderman': 7.0,
    'electrician': 6.0,
    'mechanic': 6.0,
    'hoistman': 7.0,
    'cage tender': 7.0,
    'skip tender': 7.0,

    // Emergency and communication
    'mayday': 10.0,
    'pan pan': 9.0,
    'emergency': 9.0,
    'evacuate': 9.0,
    'evacuation': 9.0,
    'code red': 9.0,
    'code blue': 9.0,
    'all clear': 7.0,
    'standby': 6.0,
    'copy that': 5.0,
    'roger': 5.0,
    'affirmative': 6.0,
    'negative': 6.0,
    'say again': 6.0,
    'repeat': 5.0,
    'break break': 7.0,
    'go ahead': 5.0,
    'wait out': 6.0,
    'over': 5.0,
    'out': 5.0,
  };

  /// Common misrecognitions mapped to correct mining terms.
  /// Used by the LLM correction layer.
  static const Map<String, String> commonErrors = {
    // Phonetic confusions
    'stop': 'stope',
    'slope': 'stope',
    'draft': 'drift',
    'rift': 'drift',
    'raze': 'raise',
    'rays': 'raise',
    'mak': 'muck',
    'mock': 'muck',
    'head frame': 'headframe',
    'lasting': 'blasting',
    'may day': 'mayday',
    'co blue': 'code blue',
    'cold blue': 'code blue',
    'code blew': 'code blue',
    'co red': 'code red',
    'cold red': 'code red',
    'code read': 'code red',
    'me thing': 'methane',
    'me dane': 'methane',
    'size mic': 'seismic',
    'ses mic': 'seismic',

    // Equipment misheard
    'alley mac': 'alimak',
    'ally mac': 'alimak',
    'skip tram': 'scooptram',
    'scoop tram': 'scooptram',
    'el aich dee': 'LHD',
    'self rescuer': 'self-rescuer',
    'cap lamp': 'cap lamp',
    'draeger': 'dräger',
    'dragger': 'dräger',

    // Operations
    'muck king': 'mucking',
    'muck in': 'mucking',
    'long hole': 'longhole',
    'sub level': 'sublevel',
    'ore past': 'ore pass',
    'waste past': 'waste pass',
    'vent bag': 'vent bag',
    'square set': 'square set',
    'cut and fill': 'cut and fill',
    'paste fill': 'paste fill',
    'shot crete': 'shotcrete',

    // Geology
    'water baring': 'water bearing',
    'pies ometer': 'piezometer',
    'piezo meter': 'piezometer',

    // Safety
    'fire damp': 'firedamp',
    'black damp': 'blackdamp',
    'after damp': 'afterdamp',
    'stink damp': 'stinkdamp',
    'rock burst': 'rockburst',
    'mud rash': 'mud rush',
    'water in rush': 'water inrush',

    // Personnel
    'shift boss': 'shift boss',
    'mine captain': 'mine captain',
    'muck operator': 'mucker operator',
    'powder man': 'powderman',
    'cage tender': 'cage tender',
    'skip tender': 'skip tender',

    // Emergency
    'pan pan pan': 'pan pan',
    'break break break': 'break break',
  };

  /// Phrases that indicate negation (should suppress alerts).
  /// Pattern: "no <keyword>", "not <keyword>", etc.
  static const List<String> negationPrefixes = [
    'no ',
    'not ',
    'without ',
    'absence of ',
    'free of ',
    'clear of ',
    'safe from ',
  ];

  /// Check if a phrase contains negated keywords.
  static bool containsNegation(String text, String keyword) {
    final lower = text.toLowerCase();
    final keywordLower = keyword.toLowerCase();

    for (final prefix in negationPrefixes) {
      // Check for "no fire", "not injured", etc.
      if (lower.contains('$prefix$keywordLower')) return true;
      // Check for "fire: no", "injured: negative", etc.
      if (lower.contains('$keywordLower: no')) return true;
      if (lower.contains('$keywordLower: negative')) return true;
    }
    return false;
  }

  /// Get hotwords formatted for Sherpa ONNX config.
  /// Returns list of "word:score" strings.
  static List<String> getHotwordsList() {
    return hotwords.entries.map((e) => '${e.key}:${e.value}').toList();
  }

  /// Apply basic correction to transcribed text using common errors map.
  static String applyBasicCorrection(String text) {
    var corrected = text;
    commonErrors.forEach((error, correction) {
      // Word boundary aware replacement
      final pattern = RegExp(r'\b' + RegExp.escape(error) + r'\b', caseSensitive: false);
      corrected = corrected.replaceAll(pattern, correction);
    });
    return corrected;
  }
}
