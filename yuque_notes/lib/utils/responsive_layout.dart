import 'package:flutter/material.dart';

/// 宽度或最短边低于阈值时使用手机端栈式布局。
/// 横屏手机 shortestSide 仍 < 600，会走手机布局（带返回）。
const double kCompactWidthBreakpoint = 720;
const double kCompactShortestSideBreakpoint = 600;

/// Desktop 左侧栏可拖拽宽度。
const double kSidebarDefaultWidth = 280;
const double kSidebarMinWidth = 72;
const double kSidebarMaxWidth = 480;
/// 低于此宽度时左侧栏改为图标缩略布局。
const double kSidebarCondensedWidth = 148;

bool isCompactLayout(BuildContext context) {
  final size = MediaQuery.sizeOf(context);
  return size.width < kCompactWidthBreakpoint ||
      size.shortestSide < kCompactShortestSideBreakpoint;
}
