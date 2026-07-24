import 'package:flutter/material.dart';

import '../l10n/app_localizations.dart';
import '../theme/app_theme.dart';

enum AppFeedbackType { success, error }

/// 统一反馈弹窗：登录/注册/退出等成功失败提示，样式对齐主题（圆角 6、主题绿/错误色）。
Future<void> showAppFeedbackDialog(
  BuildContext context, {
  required AppFeedbackType type,
  required String title,
  required String message,
  String? confirmText,
}) {
  return showDialog<void>(
    context: context,
    barrierDismissible: true,
    builder: (context) => AppFeedbackDialog(
      type: type,
      title: title,
      message: message,
      confirmText: confirmText ?? context.l10n.ok,
    ),
  );
}

Future<void> showSuccessDialog(
  BuildContext context, {
  required String title,
  required String message,
}) {
  return showAppFeedbackDialog(
    context,
    type: AppFeedbackType.success,
    title: title,
    message: message,
  );
}

Future<void> showErrorDialog(
  BuildContext context, {
  required String title,
  required String message,
}) {
  return showAppFeedbackDialog(
    context,
    type: AppFeedbackType.error,
    title: title,
    message: message,
  );
}

class AppFeedbackDialog extends StatelessWidget {
  const AppFeedbackDialog({
    super.key,
    required this.type,
    required this.title,
    required this.message,
    this.confirmText,
  });

  final AppFeedbackType type;
  final String title;
  final String message;
  final String? confirmText;

  @override
  Widget build(BuildContext context) {
    final colors = context.appColors;
    final isSuccess = type == AppFeedbackType.success;
    final accent = isSuccess ? colors.primary : colors.error;
    final icon = isSuccess ? Icons.check_circle_outline : Icons.error_outline;
    final buttonText = confirmText ?? context.l10n.ok;

    return Dialog(
      backgroundColor: colors.sidebar,
      surfaceTintColor: Colors.transparent,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(6)),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 360),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(24, 28, 24, 20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 56,
                height: 56,
                decoration: BoxDecoration(
                  color: accent.withValues(alpha: 0.12),
                  shape: BoxShape.circle,
                ),
                child: Icon(icon, size: 32, color: accent),
              ),
              const SizedBox(height: 16),
              Text(
                title,
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w600,
                  color: colors.textPrimary,
                ),
              ),
              const SizedBox(height: 10),
              Text(
                message,
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 14,
                  height: 1.45,
                  color: colors.textSecondary,
                ),
              ),
              const SizedBox(height: 24),
              SizedBox(
                width: double.infinity,
                child: isSuccess
                    ? ElevatedButton(
                        onPressed: () => Navigator.of(context).pop(),
                        child: Text(buttonText),
                      )
                    : OutlinedButton(
                        onPressed: () => Navigator.of(context).pop(),
                        style: buildAppOutlinedButtonStyle(colors).copyWith(
                          foregroundColor: WidgetStatePropertyAll(accent),
                          side: WidgetStatePropertyAll(
                            BorderSide(color: accent.withValues(alpha: 0.55)),
                          ),
                        ),
                        child: Text(buttonText),
                      ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
