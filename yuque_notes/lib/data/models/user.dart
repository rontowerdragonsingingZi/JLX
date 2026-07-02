class User {
  const User({
    required this.id,
    required this.username,
    required this.createdAt,
    this.avatar,
  });

  final int id;
  final String username;
  final DateTime createdAt;
  final String? avatar;

  factory User.fromMap(Map<String, dynamic> map) {
    return User(
      id: map['id'] as int,
      username: map['username'] as String,
      createdAt: DateTime.parse(map['created_at'] as String),
      avatar: map['avatar'] as String?,
    );
  }
}