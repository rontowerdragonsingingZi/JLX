import 'package:flutter/material.dart';

/// 宽度或最短边低于阈值时使用手机端栈式布局。
/// 横屏手机 shortestSide 仍 < 600，会走手机布局（带返回）。
const double kCompactWidthBreakpoint = 720;
const double kCompactShortestSideBreakpoint = 600;

bool isCompactLayout(BuildContext context) {
  final size = MediaQuery.sizeOf(context);
  return size.width < kCompactWidthBreakpoint ||
      size.shortestSide < kCompactShortestSideBreakpoint;
}
