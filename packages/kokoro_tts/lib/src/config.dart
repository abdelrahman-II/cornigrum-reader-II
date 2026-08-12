/// Maximum phoneme length allowed
const int maxPhonemeLength = 510;

/// Sample rate for audio output
const int sampleRate = 24000;

/// Tokenizer configuration
class TokenizerConfig {
  final String? lexiconPath;

  const TokenizerConfig({this.lexiconPath});
}

/// Core Kokoro configuration
class KokoroConfig {
  final String modelPath;
  final String voicesPath;
  final TokenizerConfig? tokenizerConfig;

  const KokoroConfig({
    required this.modelPath,
    required this.voicesPath,
    this.tokenizerConfig,
  });

  void validate() {
    if (voicesPath.isEmpty) throw ArgumentError('Voices path cannot be empty');
    if (modelPath.isEmpty) throw ArgumentError('Model path cannot be empty');
  }

  KokoroConfig copyWith({
    String? modelPath,
    String? voicesPath,
    TokenizerConfig? tokenizerConfig,
  }) {
    return KokoroConfig(
      modelPath: modelPath ?? this.modelPath,
      voicesPath: voicesPath ?? this.voicesPath,
      tokenizerConfig: tokenizerConfig ?? this.tokenizerConfig,
    );
  }
}