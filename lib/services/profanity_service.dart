/// ProfanityService — replaces profane words/phrases with **** in transcript text.
///
/// Word list derived from LDNOOBW/List-of-Dirty-Naughty-Obscene-and-Otherwise-Bad-Words
/// (https://github.com/LDNOOBW/List-of-Dirty-Naughty-Obscene-and-Otherwise-Bad-Words)
/// filtered to terms likely to appear in transcribed speech.
class ProfanityService {
  ProfanityService._();

  static const _redacted = '****';

  // Compiled once at class load time.
  static final RegExp _pattern = _buildPattern();

  static RegExp _buildPattern() {
    // Sort longest-first so multi-word phrases match before their parts.
    final sorted = List<String>.from(_wordList)
      ..sort((a, b) => b.length.compareTo(a.length));
    final escaped = sorted.map(RegExp.escape).join('|');
    return RegExp(r'\b(' + escaped + r')\b', caseSensitive: false);
  }

  /// Replace all profane words/phrases in [text] with [****].
  static String censor(String text) {
    return text.replaceAllMapped(_pattern, (_) => _redacted);
  }

  // ── Word list ─────────────────────────────────────────────────────────────
  // Single words and short phrases only — long multi-word descriptions omitted.
  static const List<String> _wordList = [
    'anal', 'anus', 'arsehole', 'ass', 'asshole', 'assmunch',
    'bastard', 'bastardo', 'bbw', 'bdsm', 'bitch', 'bitches',
    'blowjob', 'blow job', 'bollocks', 'bondage', 'boner', 'boob', 'boobs',
    'bullshit', 'bung hole', 'bunghole', 'butt', 'butthole',
    'carpet muncher', 'carpetmuncher',
    'circlejerk', 'clit', 'clitoris', 'clusterfuck', 'cock', 'cocks',
    'coon', 'coons', 'cum', 'cumming', 'cumshot', 'cumshots',
    'cunnilingus', 'cunt',
    'darkie', 'date rape', 'daterape', 'dick', 'dildo',
    'domination', 'dominatrix',
    'ejaculation', 'erotic',
    'fag', 'faggot', 'fecal', 'fellatio', 'fingerbang', 'fingering',
    'fisting', 'fuck', 'fuckin', 'fucking', 'fucktards',
    'fudge packer', 'fudgepacker',
    'gangbang', 'gang bang', 'genitals',
    'god damn', 'goddamn',
    'handjob', 'hand job', 'hardcore', 'hard core',
    'honkey', 'hooker', 'horny',
    'incest', 'intercourse',
    'jack off', 'jerk off', 'jigaboo', 'jiggaboo', 'jiggerboo', 'jizz',
    'kike',
    'masturbate', 'masturbating', 'masturbation', 'milf', 'motherfucker',
    'muff diver', 'muffdiving',
    'negro', 'neonazi', 'nigga', 'nigger', 'nig nog',
    'nipple', 'nipples', 'nude', 'nudity', 'nympho', 'nymphomania',
    'orgasm', 'orgy',
    'paedophile', 'paki', 'pedophile', 'penis',
    'piece of shit', 'pikey', 'pissing',
    'porn', 'porno', 'pornography', 'pussy',
    'raghead', 'rape', 'raping', 'rapist', 'rectum',
    'rimjob', 'rimming',
    'sadism', 'scat', 'schlong', 'semen', 'sex', 'sexo', 'sexy',
    'sexual', 'sexually', 'sexuality',
    'shemale', 'shit', 'shitty', 'skeet', 'slanteye', 'slut',
    'smut', 'snatch', 'sodomize', 'sodomy', 'spastic', 'spic',
    'spunk', 'strapon', 'strap on', 'suck', 'sucks', 'swastika',
    'tit', 'tits', 'titties', 'titty', 'tosser', 'towelhead',
    'tranny', 'twat', 'twink',
    'vagina', 'vibrator', 'voyeur',
    'wank', 'wetback', 'whore', 'white power',
    'xxx',
  ];
}
