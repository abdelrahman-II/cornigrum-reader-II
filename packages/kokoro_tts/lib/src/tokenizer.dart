import 'dart:async';
import 'dart:convert';
import 'dart:developer' as developer;
import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart'; // لتوفير دالة characters.characters
import 'package:malsami/malsami.dart';
import 'config.dart';

/// Represents a segment of text, categorized as word, punctuation, or whitespace.
class _TextPart {
  final String text;
  final String type; // "word", "punctuation", "whitespace"

  _TextPart(this.text, this.type);
}

/// Pre-compiled RegExp for splitting text (compiled once for performance).
/// Supports apostrophes within words (e.g., "don't", "it's").
final RegExp _splitRegex = RegExp(r"([a-zA-Z0-9]+(?:'[a-zA-Z0-9]+)?)|([^\w\s]+)|(\s+)");
final RegExp _digitRegex = RegExp(r'\d');

/// Splits text into words, punctuation, and whitespace parts.
List<_TextPart> _advancedSplit(String text) {
  final List<_TextPart> parts = [];

  for (final Match match in _splitRegex.allMatches(text)) {
    if (match.group(1) != null) {
      parts.add(_TextPart(match.group(1)!, 'word'));
    } else if (match.group(2) != null) {
      parts.add(_TextPart(match.group(2)!, 'punctuation'));
    } else if (match.group(3) != null) {
      parts.add(_TextPart(match.group(3)!, 'whitespace'));
    }
  }
  return parts;
}

/// Tokenizer for Kokoro TTS (English Focused)
class Tokenizer {
  static const int maxPhonemeLength = 512;

  final EnglishG2P _g2p = EnglishG2P();
  late final Map<String, int> _vocab;
  late final Map<String, String> _lexicon;
  
  bool _isInitialized = false;
  Completer<void>? _initCompleter;

  /// The configuration for this tokenizer
  final TokenizerConfig? config;

  Tokenizer({this.config});

  /// Built-in default vocabulary mapping (Kokoro TTS exact mapping).
  static const Map<String, int> _builtinVocab = {
    ";": 1, ":": 2, ",": 3, ".": 4, "!": 5, "?": 6, "—": 9, "…": 10, "\"": 11,
    "(": 12, ")": 13, "“": 14, "”": 15, " ": 16, "\u0303": 17, "ʣ": 18, "ʥ": 19,
    "ʦ": 20, "ʨ": 21, "ᵝ": 22, "\uAB67": 23, "A": 24, "I": 25, "O": 31, "Q": 33,
    "S": 35, "T": 36, "W": 39, "Y": 41, "ᵊ": 42, "a": 43, "b": 44, "c": 45,
    "d": 46, "e": 47, "f": 48, "h": 50, "i": 51, "j": 52, "k": 53, "l": 54,
    "m": 55, "n": 56, "o": 57, "p": 58, "q": 59, "r": 60, "s": 61, "t": 62,
    "u": 63, "v": 64, "w": 65, "x": 66, "y": 67, "z": 68, "ɑ": 69, "ɐ": 70,
    "ɒ": 71, "æ": 72, "β": 75, "ɔ": 76, "ɕ": 77, "ç": 78, "ɖ": 80, "ð": 81,
    "ʤ": 82, "ə": 83, "ɚ": 85, "ɛ": 86, "ɜ": 87, "ɟ": 90, "ɡ": 92, "ɥ": 99,
    "ɨ": 101, "ɪ": 102, "ʝ": 103, "ɯ": 110, "ɰ": 111, "ŋ": 112, "ɳ": 113,
    "ɲ": 114, "ɴ": 115, "ø": 116, "ɸ": 118, "θ": 119, "œ": 120, "ɹ": 123,
    "ɾ": 125, "ɻ": 126, "ʁ": 128, "ɽ": 129, "ʂ": 130, "ʃ": 131, "ʈ": 132,
    "ʧ": 133, "ʊ": 135, "ʋ": 136, "ʌ": 138, "ɣ": 139, "ɤ": 140, "χ": 142,
    "ʎ": 143, "ʒ": 147, "ʔ": 148, "ˈ": 156, "ˌ": 157, "ː": 158, "ʰ": 162,
    "ʲ": 164, "↓": 169, "→": 171, "↗": 172, "↘": 173, "ᵻ": 177
  };

  /// Ensures single initialization thread-safely
  Future<void> ensureInitialized() async {
    if (_isInitialized) return;
    if (_initCompleter != null) return _initCompleter!.future;

    _initCompleter = Completer<void>();
    try {
      await _initialize();
      _isInitialized = true;
      _initCompleter!.complete();
    } catch (e, st) {
      _initCompleter!.completeError(e, st);
      _initCompleter = null; // Reset on error to allow retry
      rethrow;
    }
  }

  /// Initializes all assets, lexicons, and vocabulary once
  Future<void> _initialize() async {
    final lexicon = Lexicon(false); // false for American English

    // Load Malsami assets concurrently
    final results = await Future.wait([
      rootBundle.loadString('packages/malsami/assets/us_gold.json'),
      rootBundle.loadString('packages/malsami/assets/us_silver.json'),
      _loadVocabularyData(),
      _loadLexiconData(),
    ]);

    final String goldJson = results[0] as String;
    final String silverJson = results[1] as String;
    _vocab = results[2] as Map<String, int>;
    _lexicon = results[3] as Map<String, String>;

    lexicon.golds = lexicon.growDictionary(json.decode(goldJson) as Map<String, dynamic>);
    lexicon.silvers = lexicon.growDictionary(json.decode(silverJson) as Map<String, dynamic>);

    // Merge custom lexicon into gold dictionary directly in bulk
    if (_lexicon.isNotEmpty) {
      lexicon.golds.addAll(_lexicon);
    }

    _g2p.lexicon = lexicon;
  }

  Future<Map<String, int>> _loadVocabularyData() async {
    try {
      final jsonString = await rootBundle.loadString('assets/tokenizer_vocab.json');
      final Map<String, dynamic> vocabMap = Map<String, dynamic>.from(jsonDecode(jsonString));
      final result = vocabMap.map((k, v) => MapEntry(k, v as int));
      developer.log('Loaded vocabulary from asset with ${result.length} entries', name: 'kokoro_tokenizer');
      return result;
    } catch (e) {
      developer.log('Using fallback built-in vocabulary map (${_builtinVocab.length} entries)', name: 'kokoro_tokenizer');
      return Map<String, int>.from(_builtinVocab);
    }
  }

  Future<Map<String, String>> _loadLexiconData() async {
    try {
      final lexiconPath = config?.lexiconPath ?? 'assets/lexicon.json';
      final jsonString = await rootBundle.loadString(lexiconPath);
      final Map<String, dynamic> lexiconMap = Map<String, dynamic>.from(jsonDecode(jsonString));
      final result = lexiconMap.map((k, v) => MapEntry(k.toLowerCase(), v as String));
      developer.log('Loaded lexicon with ${result.length} entries', name: 'kokoro_tokenizer');
      return result;
    } catch (e) {
      developer.log('Warning: Failed to load lexicon: $e', name: 'kokoro_tokenizer');
      return {};
    }
  }

  static String normalizeText(String text) {
    return text.trim();
  }

  Future<(String, List<MToken>)> phonemizeWithTokens(String text, String lang) async {
    await ensureInitialized();
    final normalizedText = normalizeText(text);

    final (phonemes, tokens) = await _g2p.convert(normalizedText);
    developer.log('Phonemes: $phonemes', name: 'kokoro_tokenizer');
    return (phonemes, tokens);
  }

  Future<String> phonemize(String text, {String lang = 'en-us'}) async {
    await ensureInitialized();

    if (text.isEmpty) return '';

    final List<_TextPart> parts = _advancedSplit(text);
    final StringBuffer resultBuffer = StringBuffer();

    for (final _TextPart part in parts) {
      switch (part.type) {
        case 'word':
          final String wordToProcess = part.text;
          final String? lexiconPhonemes = _lexicon[wordToProcess.toLowerCase()];

          if (lexiconPhonemes != null) {
            resultBuffer.write(lexiconPhonemes);
          } else {
            final (phonemes, _) = await _g2p.convert(wordToProcess);
            String phonemesFromG2P = phonemes;

            if ((phonemesFromG2P.trim().isEmpty || phonemesFromG2P == '❓') && wordToProcess.isNotEmpty) {
              phonemesFromG2P = _attemptRuleBasedFallback(wordToProcess);
              if (phonemesFromG2P.isEmpty) {
                phonemesFromG2P = _generateFallbackPhonemes(wordToProcess);
              }
            }
            resultBuffer.write(phonemesFromG2P);
          }
          break;
        case 'punctuation':
        case 'whitespace':
          resultBuffer.write(part.text);
          break;
      }
    }
    return resultBuffer.toString();
  }

  List<int> tokenize(String phonemes) {
    if (phonemes.length > maxPhonemeLength) {
      throw Exception('Text is too long, must be less than $maxPhonemeLength phonemes');
    }

    final List<int> tokens = [];
    // Iterate using characters to handle multi-byte Unicode/IPA symbols correctly
    for (final char in phonemes.characters) {
      final tokenId = _vocab[char];
      if (tokenId != null) {
        tokens.add(tokenId);
      }
    }
    developer.log('Tokenized phonemes: "$phonemes" -> ${tokens.length} tokens', name: 'kokoro_tokenizer');
    return tokens;
  }

  void debugPunctuationProcessing(String text) async {
    developer.log('PUNCTUATION DEBUG: Original text: "$text"', name: 'kokoro_tokenizer');
  }

  // --- Static Rules & Fast Lookup Tables ---

  static const Map<String, String> _letterPhonemes = {
    'a': 'ˈeɪ', 'b': 'bˈiː', 'c': 'sˈiː', 'd': 'dˈiː', 'e': 'ˈiː',
    'f': 'ˈɛf', 'g': 'ʤˈiː', 'h': 'ˈeɪʧ', 'i': 'ˈaɪ', 'j': 'ʤˈeɪ',
    'k': 'kˈeɪ', 'l': 'ˈɛl', 'm': 'ˈɛm', 'n': 'ˈɛn', 'o': 'ˈoʊ',
    'p': 'pˈiː', 'q': 'kjˈuː', 'r': 'ˈɑːɹ', 's': 'ˈɛs', 't': 'tˈiː',
    'u': 'jˈuː', 'v': 'vˈiː', 'w': 'dˈʌbəljuː', 'x': 'ˈɛks', 'y': 'wˈaɪ',
    'z': 'zˈiː',
    '0': 'zˈɪəɹoʊ', '1': 'wˈʌn', '2': 'tˈuː', '3': 'θɹˈiː', '4': 'fˈɔːɹ',
    '5': 'fˈaɪv', '6': 'sˈɪks', '7': 'sˈɛvən', '8': 'ˈeɪt', '9': 'nˈaɪn'
  };

  static final Map<String, String> _graphemePhonemeRules = {
    'tion': 'ʃən', 'sion': 'ʃən', 'ious': 'iəs', 'ness': 'nəs', 'ment': 'mənt',
    'able': 'əbəl', 'ible': 'ɪbəl', 'ing': 'ɪŋ', 'ful': 'fəl', 'less': 'ləs',
    'ly': 'li', 'er': 'ɚ', 'est': 'ɪst', 'igh': 'aɪ', 'tch': 'tʃ', 'dge': 'dʒ',
    'eau': 'oʊ', 'sh': 'ʃ', 'ch': 'tʃ', 'th': 'θ', 'ph': 'f', 'kn': 'n',
    'wr': 'r', 'wh': 'w', 'ng': 'ŋ', 'ck': 'k', 'sc': 'sk', 'qu': 'kw',
    'gu': 'g', 'mb': 'm', 'bt': 't', 'ee': 'iː', 'ea': 'iː', 'oo': 'uː',
    'ai': 'eɪ', 'ay': 'eɪ', 'oi': 'ɔɪ', 'oy': 'ɔɪ', 'ou': 'aʊ', 'ow': 'aʊ',
    'au': 'ɔː', 'aw': 'ɔː', 'ew': 'juː', 'ey': 'eɪ', 'ie': 'iː', 'oa': 'oʊ',
    'oe': 'oʊ', 'ue': 'uː', 'ui': 'uː',
  };

  /// Pre-sorted rules by length (Longest match first for Maximal Munch), created ONCE.
  static final List<MapEntry<String, String>> _sortedGraphemeRules =
      _graphemePhonemeRules.entries.toList()
        ..sort((a, b) => b.key.length.compareTo(a.key.length));

  static const Map<String, String> _singleGraphemePhonemes = {
    'a': 'æ', 'b': 'b', 'c': 'k', 'd': 'd', 'e': 'ɛ', 'f': 'f', 'g': 'ɡ',
    'h': 'h', 'i': 'ɪ', 'j': 'dʒ', 'k': 'k', 'l': 'l', 'm': 'm', 'n': 'n',
    'o': 'ɒ', 'p': 'p', 'q': 'k', 'r': 'ɹ', 's': 's', 't': 't', 'u': 'ʌ',
    'v': 'v', 'w': 'w', 'x': 'ks', 'y': 'j', 'z': 'z',
  };

  String _attemptRuleBasedFallback(String word) {
    final lowerWord = word.toLowerCase();
    final buffer = StringBuffer();
    int i = 0;

    while (i < lowerWord.length) {
      bool ruleApplied = false;

      for (final entry in _sortedGraphemeRules) {
        final ruleKey = entry.key;
        if (i + ruleKey.length <= lowerWord.length &&
            lowerWord.substring(i, i + ruleKey.length) == ruleKey) {
          buffer.write(entry.value);
          i += ruleKey.length;
          ruleApplied = true;
          break;
        }
      }

      if (!ruleApplied) {
        final char = lowerWord[i];
        if (_singleGraphemePhonemes.containsKey(char)) {
          buffer.write(_singleGraphemePhonemes[char]!);
        } else if (_digitRegex.hasMatch(char) && _letterPhonemes.containsKey(char)) {
          buffer.write(_letterPhonemes[char]!);
        } else {
          buffer.write('?');
        }
        i++;
      }
    }
    return buffer.toString();
  }

  String _generateFallbackPhonemes(String word) {
    final lowerWord = word.toLowerCase();
    final buffer = StringBuffer();

    for (int i = 0; i < lowerWord.length; i++) {
      final char = lowerWord[i];
      if (_letterPhonemes.containsKey(char)) {
        if (buffer.isNotEmpty) buffer.write(' ');
        buffer.write(_letterPhonemes[char]!);
      }
    }
    return buffer.toString();
  }
}