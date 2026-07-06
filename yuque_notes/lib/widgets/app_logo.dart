import 'package:flutter/material.dart';

class AppAssets {
  static const String appLogo = 'assets/images/app_logo.png';
}

class AppLogo extends StatelessWidget {
  const AppLogo({
    super.key,
    this.size = 40,
  });

  final double size;

  @override
  Widget build(BuildContext context) {
    final devicePixelRatio = MediaQuery.devicePixelRatioOf(context);
    final cacheSize = (size * devicePixelRatio).round().clamp(64, 2048);

    return Image.asset(
      AppAssets.appLogo,
      width: size,
      height: size,
      fit: BoxFit.contain,
      filterQuality: FilterQuality.high,
      cacheWidth: cacheSize,
      cacheHeight: cacheSize,
      gaplessPlayback: true,
      excludeFromSemantics: true,
    );
  }
}