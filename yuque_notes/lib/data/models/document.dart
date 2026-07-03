class Document {
  const Document({
    required this.id,
    required this.userId,
    required this.folderId,
    required this.title,
    required this.content,
    required this.createdAt,
    required this.updatedAt,
    this.syncedToCommunity = false,
  });

  final int id;
  final int userId;
  final int folderId;
  final String title;
  final String content;
  final DateTime createdAt;
  final DateTime updatedAt;
  final bool syncedToCommunity;

  factory Document.fromMap(Map<String, dynamic> map) {
    return Document(
      id: map['id'] as int,
      userId: map['user_id'] as int,
      folderId: map['folder_id'] as int,
      title: map['title'] as String,
      content: map['content'] as String,
      createdAt: DateTime.parse(map['created_at'] as String),
      updatedAt: DateTime.parse(map['updated_at'] as String),
      syncedToCommunity: (map['synced_to_community'] as int? ?? 0) == 1,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'user_id': userId,
      'folder_id': folderId,
      'title': title,
      'content': content,
      'created_at': createdAt.toIso8601String(),
      'updated_at': updatedAt.toIso8601String(),
      'synced_to_community': syncedToCommunity ? 1 : 0,
    };
  }

  Document copyWith({
    int? id,
    int? userId,
    int? folderId,
    String? title,
    String? content,
    DateTime? createdAt,
    DateTime? updatedAt,
    bool? syncedToCommunity,
  }) {
    return Document(
      id: id ?? this.id,
      userId: userId ?? this.userId,
      folderId: folderId ?? this.folderId,
      title: title ?? this.title,
      content: content ?? this.content,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      syncedToCommunity: syncedToCommunity ?? this.syncedToCommunity,
    );
  }
}