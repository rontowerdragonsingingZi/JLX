import 'dart:convert';

import 'package:flutter/material.dart';

import '../editor/image_storage.dart';
import '../theme/app_theme.dart';

class UserAvatar extends StatelessWidget {
  const UserAvatar({
    super.key,
    required this.avatar,
    this.radius = 18,
    this.onTap,
  });

  /// 支持 Data URI 或 https/http R2 URL。
  final String? avatar;
  final double radius;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final colors = context.appColors;
    final image = _avatarImage(avatar);
    final avatarWidget = CircleAvatar(
      key: const Key('user_avatar'),
      radius: radius,
      backgroundColor: colors.border,
      backgroundImage: image,
      child: image == null
          ? Icon(
              Icons.person,
              key: const Key('user_avatar_default'),
              size: radius,
              color: colors.textSecondary,
            )
          : null,
    );

    if (onTap == null) {
      return avatarWidget;
    }

    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(radius),
      child: avatarWidget,
    );
  }

  ImageProvider? _avatarImage(String? source) {
    if (source == null || source.isEmpty || !isAvatarImageSource(source)) {
      return null;
    }

    // 云端 R2 / 普通 HTTPS 头像
    final uri = Uri.tryParse(source);
    if (uri != null &&
        (uri.scheme == 'https' || uri.scheme == 'http') &&
        uri.host.isNotEmpty) {
      return NetworkImage(source);
    }

    // 历史/兼容：data:image/...;base64,...
    if (!isPortableImageSource(source)) {
      return null;
    }
    final commaIndex = source.indexOf(',');
    if (commaIndex < 0) {
      return null;
    }
    try {
      final bytes = base64Decode(source.substring(commaIndex + 1));
      if (bytes.isEmpty) {
        return null;
      }
      return MemoryImage(bytes);
    } on FormatException {
      return null;
    }
  }
}
