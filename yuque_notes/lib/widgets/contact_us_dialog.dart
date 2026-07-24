import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../app_branding.dart';
import '../l10n/app_localizations.dart';
import '../theme/app_theme.dart';

/// 底部「联系我们」入口打开的说明 + 联系方式模态框。
Future<void> showContactUsDialog(BuildContext context) {
  return showDialog<void>(
    context: context,
    builder: (context) => const ContactUsDialog(),
  );
}

class ContactUsDialog extends StatelessWidget {
  const ContactUsDialog({super.key});

  static const String gmail = 'yb8495812@gmail.com';
  static const String qqMail = 'yabo2003@qq.com';

  Future<void> _copy(BuildContext context, String value, String label) async {
    await Clipboard.setData(ClipboardData(text: value));
    if (!context.mounted) {
      return;
    }
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(context.l10n.copiedLabel(label))),
    );
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.appColors;
    final l10n = context.l10n;
    final width = MediaQuery.sizeOf(context).width;
    final compact = width < 720;
    final maxWidth = compact ? width - 32.0 : 520.0;

    return Dialog(
      insetPadding: EdgeInsets.symmetric(
        horizontal: compact ? 16 : 40,
        vertical: compact ? 24 : 40,
      ),
      child: ConstrainedBox(
        constraints: BoxConstraints(
          maxWidth: maxWidth,
          maxHeight: MediaQuery.sizeOf(context).height * 0.9,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 12, 8, 8),
              child: Row(
                children: [
                  Expanded(
                    child: Text(
                      l10n.contactUs,
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.w600,
                        color: colors.textPrimary,
                      ),
                    ),
                  ),
                  IconButton(
                    tooltip: l10n.close,
                    onPressed: () => Navigator.of(context).pop(),
                    icon: const Icon(Icons.close),
                  ),
                ],
              ),
            ),
            Divider(height: 1, color: colors.border),
            Flexible(
              child: SingleChildScrollView(
                padding: const EdgeInsets.fromLTRB(20, 16, 20, 20),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Text(
                      AppBranding.fullName,
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                        color: colors.primary,
                      ),
                    ),
                    const SizedBox(height: 12),
                    Text(
                      l10n.contactAbout,
                      style: TextStyle(
                        fontSize: 14,
                        height: 1.55,
                        color: colors.textPrimary,
                      ),
                    ),
                    const SizedBox(height: 20),
                    Text(
                      l10n.contactMethods,
                      style: TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w600,
                        color: colors.textPrimary,
                      ),
                    ),
                    const SizedBox(height: 12),
                    Wrap(
                      spacing: 12,
                      runSpacing: 12,
                      alignment: WrapAlignment.center,
                      children: [
                        const _QrCard(
                          title: 'QQ',
                          assetPath: 'assets/images/contact/qq_qr.png',
                        ),
                        _QrCard(
                          title: l10n.wechat,
                          assetPath: 'assets/images/contact/wechat_qr.png',
                        ),
                        const _QrCard(
                          title: 'Telegram',
                          assetPath: 'assets/images/contact/tg_qr.png',
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),
                    _EmailTile(
                      label: 'Gmail',
                      email: gmail,
                      onCopy: () => _copy(context, gmail, 'Gmail'),
                    ),
                    const SizedBox(height: 8),
                    _EmailTile(
                      label: l10n.qqMail,
                      email: qqMail,
                      onCopy: () => _copy(context, qqMail, l10n.qqMail),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _QrCard extends StatelessWidget {
  const _QrCard({
    required this.title,
    required this.assetPath,
  });

  final String title;
  final String assetPath;

  @override
  Widget build(BuildContext context) {
    final colors = context.appColors;
    final size = MediaQuery.sizeOf(context).width < 720 ? 120.0 : 140.0;

    return Container(
      width: size + 24,
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: colors.sidebar,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: colors.primary.withValues(alpha: 0.35)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            title,
            style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w600,
              color: colors.textPrimary,
            ),
          ),
          const SizedBox(height: 8),
          ClipRRect(
            borderRadius: BorderRadius.circular(6),
            child: Image.asset(
              assetPath,
              width: size,
              height: size,
              fit: BoxFit.contain,
              errorBuilder: (context, error, stackTrace) => SizedBox(
                width: size,
                height: size,
                child: Center(
                  child: Text(
                    context.l10n.qrLoadFailed,
                    style: TextStyle(fontSize: 12, color: colors.error),
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _EmailTile extends StatelessWidget {
  const _EmailTile({
    required this.label,
    required this.email,
    required this.onCopy,
  });

  final String label;
  final String email;
  final VoidCallback onCopy;

  @override
  Widget build(BuildContext context) {
    final colors = context.appColors;
    return Material(
      color: colors.hover.withValues(alpha: 0.5),
      borderRadius: BorderRadius.circular(8),
      child: InkWell(
        borderRadius: BorderRadius.circular(8),
        onTap: onCopy,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
          child: Row(
            children: [
              Icon(Icons.email_outlined, size: 20, color: colors.primary),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      label,
                      style: TextStyle(
                        fontSize: 12,
                        color: colors.textSecondary,
                      ),
                    ),
                    Text(
                      email,
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w500,
                        color: colors.textPrimary,
                      ),
                    ),
                  ],
                ),
              ),
              Text(
                context.l10n.copy,
                style: TextStyle(fontSize: 13, color: colors.primary),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
