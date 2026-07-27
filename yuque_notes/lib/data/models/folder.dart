class Folder {
  const Folder({
    required this.id,
    required this.userId,
    required this.parentId,
    required this.name,
    required this.createdAt,
    required this.updatedAt,
    this.sortOrder = 0,
  });

  final int id;
  final int userId;
  final int? parentId;
  final String name;
  final DateTime createdAt;
  final DateTime updatedAt;
  final int sortOrder;

  factory Folder.fromMap(Map<String, dynamic> map) {
    return Folder(
      id: map['id'] as int,
      userId: map['user_id'] as int,
      parentId: map['parent_id'] as int?,
      name: map['name'] as String,
      createdAt: DateTime.parse(map['created_at'] as String),
      updatedAt: DateTime.parse(map['updated_at'] as String),
      sortOrder: (map['sort_order'] as int?) ?? 0,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'user_id': userId,
      'parent_id': parentId,
      'name': name,
      'created_at': createdAt.toIso8601String(),
      'updated_at': updatedAt.toIso8601String(),
      'sort_order': sortOrder,
    };
  }

  Folder copyWith({
    int? id,
    int? userId,
    int? parentId,
    bool clearParentId = false,
    String? name,
    DateTime? createdAt,
    DateTime? updatedAt,
    int? sortOrder,
  }) {
    return Folder(
      id: id ?? this.id,
      userId: userId ?? this.userId,
      parentId: clearParentId ? null : (parentId ?? this.parentId),
      name: name ?? this.name,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      sortOrder: sortOrder ?? this.sortOrder,
    );
  }
}
