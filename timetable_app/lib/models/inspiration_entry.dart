class InspirationEntry {
  const InspirationEntry({
    required this.id,
    required this.content,
    required this.createdAt,
    required this.updatedAt,
  });

  final String id;
  final String content;
  final DateTime createdAt;
  final DateTime updatedAt;

  InspirationEntry copyWith({String? content, DateTime? updatedAt}) {
    return InspirationEntry(
      id: id,
      content: content ?? this.content,
      createdAt: createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'content': content,
      'createdAt': createdAt.toIso8601String(),
      'updatedAt': updatedAt.toIso8601String(),
    };
  }

  factory InspirationEntry.fromJson(Map<String, dynamic> json) {
    final created =
        DateTime.tryParse(json['createdAt']?.toString() ?? '') ??
        DateTime.now();
    return InspirationEntry(
      id: json['id']?.toString() ?? created.microsecondsSinceEpoch.toString(),
      content: json['content']?.toString() ?? '',
      createdAt: created,
      updatedAt:
          DateTime.tryParse(json['updatedAt']?.toString() ?? '') ?? created,
    );
  }
}
