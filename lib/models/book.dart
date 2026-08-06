import 'chapter.dart';

class Book {
  final String id;
  final String title;
  final String author;
  final String? coverPath;
  final String? filePath;
  final List<Chapter> chapters;
  final int currentChapterIndex;
  final int currentSentenceIndex;
  final double progressPercent;
  final bool isFavorite;
  final DateTime? lastReadAt;
  final DateTime? addedAt;
  final int totalListeningSeconds;

  const Book({
    required this.id,
    required this.title,
    required this.author,
    this.coverPath,
    this.filePath,
    required this.chapters,
    this.currentChapterIndex = 0,
    this.currentSentenceIndex = 0,
    this.progressPercent = 0.0,
    this.isFavorite = false,
    this.lastReadAt,
    this.addedAt,
    this.totalListeningSeconds = 0,
  });

  Book copyWith({
    String? id,
    String? title,
    String? author,
    String? coverPath,
    String? filePath,
    List<Chapter>? chapters,
    int? currentChapterIndex,
    int? currentSentenceIndex,
    double? progressPercent,
    bool? isFavorite,
    DateTime? lastReadAt,
    DateTime? addedAt,
    int? totalListeningSeconds,
  }) {
    return Book(
      id: id ?? this.id,
      title: title ?? this.title,
      author: author ?? this.author,
      coverPath: coverPath ?? this.coverPath,
      filePath: filePath ?? this.filePath,
      chapters: chapters ?? this.chapters,
      currentChapterIndex: currentChapterIndex ?? this.currentChapterIndex,
      currentSentenceIndex: currentSentenceIndex ?? this.currentSentenceIndex,
      progressPercent: progressPercent ?? this.progressPercent,
      isFavorite: isFavorite ?? this.isFavorite,
      lastReadAt: lastReadAt ?? this.lastReadAt,
      addedAt: addedAt ?? this.addedAt,
      totalListeningSeconds: totalListeningSeconds ?? this.totalListeningSeconds,
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'title': title,
        'author': author,
        'coverPath': coverPath,
        'filePath': filePath,
        'chapters': chapters.map((c) => c.toJson()).toList(),
        'currentChapterIndex': currentChapterIndex,
        'currentSentenceIndex': currentSentenceIndex,
        'progressPercent': progressPercent,
        'isFavorite': isFavorite,
        'lastReadAt': lastReadAt?.toIso8601String(),
        'addedAt': addedAt?.toIso8601String(),
        'totalListeningSeconds': totalListeningSeconds,
      };

  factory Book.fromJson(Map<String, dynamic> json) => Book(
        id: json['id'],
        title: json['title'],
        author: json['author'],
        coverPath: json['coverPath'],
        filePath: json['filePath'],
        chapters: (json['chapters'] as List? ?? [])
            .map((c) => Chapter.fromJson(c as Map<String, dynamic>))
            .toList(),
        currentChapterIndex: json['currentChapterIndex'] ?? 0,
        currentSentenceIndex: json['currentSentenceIndex'] ?? 0,
        progressPercent: (json['progressPercent'] ?? 0.0).toDouble(),
        isFavorite: json['isFavorite'] ?? false,
        lastReadAt: json['lastReadAt'] != null
            ? DateTime.parse(json['lastReadAt'])
            : null,
        addedAt:
            json['addedAt'] != null ? DateTime.parse(json['addedAt']) : null,
        totalListeningSeconds: json['totalListeningSeconds'] ?? 0,
      );
}
