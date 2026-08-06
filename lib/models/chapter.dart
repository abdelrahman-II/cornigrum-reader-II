class Chapter {
  final String id;
  final String title;
  final String content;
  final int sentenceCount;
  final int currentSentenceIndex;
  final double completionPercent;

  const Chapter({
    required this.id,
    required this.title,
    required this.content,
    this.sentenceCount = 0,
    this.currentSentenceIndex = 0,
    this.completionPercent = 0.0,
  });

  Chapter copyWith({
    String? id,
    String? title,
    String? content,
    int? sentenceCount,
    int? currentSentenceIndex,
    double? completionPercent,
  }) {
    return Chapter(
      id: id ?? this.id,
      title: title ?? this.title,
      content: content ?? this.content,
      sentenceCount: sentenceCount ?? this.sentenceCount,
      currentSentenceIndex: currentSentenceIndex ?? this.currentSentenceIndex,
      completionPercent: completionPercent ?? this.completionPercent,
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'title': title,
        'content': content,
        'sentenceCount': sentenceCount,
        'currentSentenceIndex': currentSentenceIndex,
        'completionPercent': completionPercent,
      };

  factory Chapter.fromJson(Map<String, dynamic> json) => Chapter(
        id: json['id'],
        title: json['title'],
        content: json['content'],
        sentenceCount: json['sentenceCount'] ?? 0,
        currentSentenceIndex: json['currentSentenceIndex'] ?? 0,
        completionPercent: (json['completionPercent'] ?? 0.0).toDouble(),
      );
}
