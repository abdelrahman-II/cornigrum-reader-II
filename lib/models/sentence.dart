class Sentence {
  final int index;
  final String text;
  final bool isHighlighted;
  final bool isSynthesized;
  final String? audioBufferRef;
  final int durationMs;
  final int charStart;
  final int charEnd;

  const Sentence({
    required this.index,
    required this.text,
    this.charStart = 0,
    this.charEnd = 0,
    this.isHighlighted = false,
    this.isSynthesized = false,
    this.audioBufferRef,
    this.durationMs = 0,
  });

  Sentence copyWith({
    int? index,
    String? text,
    bool? isHighlighted,
    bool? isSynthesized,
    String? audioBufferRef,
    int? durationMs,
    int? charStart,
    int? charEnd,
  }) {
    return Sentence(
      index: index ?? this.index,
      text: text ?? this.text,
      isHighlighted: isHighlighted ?? this.isHighlighted,
      isSynthesized: isSynthesized ?? this.isSynthesized,
      audioBufferRef: audioBufferRef ?? this.audioBufferRef,
      durationMs: durationMs ?? this.durationMs,
      charStart: charStart ?? this.charStart,
      charEnd: charEnd ?? this.charEnd,
    );
  }

  Map<String, dynamic> toJson() => {
        'index': index,
        'text': text,
        'isHighlighted': isHighlighted,
        'isSynthesized': isSynthesized,
        'audioBufferRef': audioBufferRef,
        'durationMs': durationMs,
        'charStart': charStart,
        'charEnd': charEnd,
      };

  factory Sentence.fromJson(Map<String, dynamic> json) => Sentence(
        index: json['index'],
        text: json['text'],
        isHighlighted: json['isHighlighted'] ?? false,
        isSynthesized: json['isSynthesized'] ?? false,
        audioBufferRef: json['audioBufferRef'],
        durationMs: json['durationMs'] ?? 0,
        charStart: json['charStart'] ?? 0,
        charEnd: json['charEnd'] ?? 0,
    );
}
