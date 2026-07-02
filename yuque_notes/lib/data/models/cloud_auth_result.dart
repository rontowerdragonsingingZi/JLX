class CloudAuthResult {
  const CloudAuthResult({
    required this.accessToken,
    required this.userId,
    required this.username,
    this.refreshToken,
    this.avatar,
  });

  final String accessToken;
  final String? refreshToken;
  final int userId;
  final String username;
  final String? avatar;
}