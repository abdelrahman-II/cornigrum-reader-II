class Voice {
  final String id;
  final String name;
  final String embeddingPath;
  final int embeddingDim;
  final String? description;
  final bool isBuiltIn;

  const Voice({
    required this.id,
    required this.name,
    required this.embeddingPath,
    this.embeddingDim = 128,
    this.description,
    this.isBuiltIn = true,
  });

  Voice copyWith({
    String? id,
    String? name,
    String? embeddingPath,
    int? embeddingDim,
    String? description,
    bool? isBuiltIn,
  }) {
    return Voice(
      id: id ?? this.id,
      name: name ?? this.name,
      embeddingPath: embeddingPath ?? this.embeddingPath,
      embeddingDim: embeddingDim ?? this.embeddingDim,
      description: description ?? this.description,
      isBuiltIn: isBuiltIn ?? this.isBuiltIn,
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'name': name,
        'embeddingPath': embeddingPath,
        'embeddingDim': embeddingDim,
        'description': description,
        'isBuiltIn': isBuiltIn,
      };

  factory Voice.fromJson(Map<String, dynamic> json) => Voice(
        id: json['id'],
        name: json['name'],
        embeddingPath: json['embeddingPath'],
        embeddingDim: json['embeddingDim'] ?? 128,
        description: json['description'],
        isBuiltIn: json['isBuiltIn'] ?? true,
      );
}
