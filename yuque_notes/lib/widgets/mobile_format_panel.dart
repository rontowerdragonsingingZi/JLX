import 'package:flutter/material.dart';
import 'package:flutter_quill/flutter_quill.dart';

import '../l10n/app_localizations.dart';
import '../theme/app_theme.dart';

/// 手机端富文本格式侧栏：每项带简短 title，便于无 hover 时理解功能。
class MobileFormatPanel extends StatelessWidget {
  const MobileFormatPanel({
    super.key,
    required this.controller,
    required this.onClose,
    required this.onInsertImage,
    required this.onResizeImage,
    required this.onInsertSnippet,
  });

  final QuillController controller;
  final VoidCallback onClose;
  final VoidCallback onInsertImage;
  final VoidCallback onResizeImage;
  final VoidCallback onInsertSnippet;

  void _toggle(Attribute attribute) {
    final attrs = controller.getSelectionStyle().attributes;
    if (attrs.containsKey(attribute.key) &&
        attrs[attribute.key]?.value == attribute.value) {
      controller.formatSelection(Attribute.clone(attribute, null));
    } else if (attrs.containsKey(attribute.key) && attribute.value is bool) {
      controller.formatSelection(Attribute.clone(attribute, null));
    } else {
      controller.formatSelection(attribute);
    }
  }

  void _applyOrClear(Attribute attribute, {required bool clear}) {
    if (clear) {
      controller.formatSelection(Attribute.clone(attribute, null));
    } else {
      controller.formatSelection(attribute);
    }
  }

  bool _has(Attribute attribute) {
    final current = controller.getSelectionStyle().attributes[attribute.key];
    if (current == null) {
      return false;
    }
    if (attribute.value == null) {
      return true;
    }
    return current.value == attribute.value;
  }

  bool _hasKey(String key) {
    return controller.getSelectionStyle().attributes.containsKey(key);
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.appColors;
    final l10n = context.l10n;
    final colorEntries = <MapEntry<String, Color>>[
      MapEntry(l10n.colorBlack, const Color(0xFF262626)),
      MapEntry(l10n.colorRed, const Color(0xFFE53935)),
      MapEntry(l10n.colorOrange, const Color(0xFFFB8C00)),
      MapEntry(l10n.colorGreen, const Color(0xFF00B96B)),
      MapEntry(l10n.colorBlue, const Color(0xFF1E88E5)),
      MapEntry(l10n.colorPurple, const Color(0xFF8E24AA)),
    ];

    return Material(
      elevation: 8,
      color: colors.sidebar,
      child: SafeArea(
        left: false,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(12, 8, 4, 8),
              child: Row(
                children: [
                  Expanded(
                    child: Text(
                      l10n.formatTools,
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                        color: colors.textPrimary,
                      ),
                    ),
                  ),
                  IconButton(
                    key: const Key('mobile_format_panel_close'),
                    tooltip: l10n.close,
                    onPressed: onClose,
                    icon: const Icon(Icons.close),
                  ),
                ],
              ),
            ),
            Divider(height: 1, color: colors.border),
            Expanded(
              child: ListenableBuilder(
                listenable: controller,
                builder: (context, _) {
                  return ListView(
                    padding: const EdgeInsets.fromLTRB(10, 8, 10, 24),
                    children: [
                      _SectionTitle(title: l10n.sectionEdit, colors: colors),
                      _FormatTile(
                        icon: Icons.undo,
                        title: l10n.undo,
                        subtitle: l10n.undoHint,
                        colors: colors,
                        onTap: controller.hasUndo ? controller.undo : null,
                      ),
                      _FormatTile(
                        icon: Icons.redo,
                        title: l10n.redo,
                        subtitle: l10n.redoHint,
                        colors: colors,
                        onTap: controller.hasRedo ? controller.redo : null,
                      ),
                      _SectionTitle(title: l10n.sectionTextStyle, colors: colors),
                      _FormatTile(
                        icon: Icons.format_bold,
                        title: l10n.bold,
                        subtitle: l10n.boldHint,
                        selected: _has(Attribute.bold),
                        colors: colors,
                        onTap: () => _toggle(Attribute.bold),
                      ),
                      _FormatTile(
                        icon: Icons.format_italic,
                        title: l10n.italic,
                        subtitle: l10n.italicHint,
                        selected: _has(Attribute.italic),
                        colors: colors,
                        onTap: () => _toggle(Attribute.italic),
                      ),
                      _FormatTile(
                        icon: Icons.format_underlined,
                        title: l10n.underline,
                        subtitle: l10n.underlineHint,
                        selected: _has(Attribute.underline),
                        colors: colors,
                        onTap: () => _toggle(Attribute.underline),
                      ),
                      _FormatTile(
                        icon: Icons.strikethrough_s,
                        title: l10n.strikethrough,
                        subtitle: l10n.strikethroughHint,
                        selected: _has(Attribute.strikeThrough),
                        colors: colors,
                        onTap: () => _toggle(Attribute.strikeThrough),
                      ),
                      _FormatTile(
                        icon: Icons.format_clear,
                        title: l10n.clearFormat,
                        subtitle: l10n.clearFormatHint,
                        colors: colors,
                        onTap: () {
                          for (final key in [
                            Attribute.bold.key,
                            Attribute.italic.key,
                            Attribute.underline.key,
                            Attribute.strikeThrough.key,
                            Attribute.size.key,
                            Attribute.color.key,
                          ]) {
                            final origin = Attribute.fromKeyValue(key, null);
                            if (origin != null) {
                              controller.formatSelection(
                                Attribute.clone(origin, null),
                              );
                            }
                          }
                        },
                      ),
                      _SectionTitle(title: l10n.sectionFontSize, colors: colors),
                      _FormatTile(
                        icon: Icons.text_fields,
                        title: l10n.sizeDefault,
                        subtitle: l10n.sizeDefaultHint,
                        selected: !_hasKey(Attribute.size.key),
                        colors: colors,
                        onTap: () => _applyOrClear(
                          const SizeAttribute(null),
                          clear: true,
                        ),
                      ),
                      _FormatTile(
                        icon: Icons.text_decrease,
                        title: l10n.sizeSmall,
                        subtitle: l10n.sizeSmallHint,
                        selected: _has(const SizeAttribute('small')),
                        colors: colors,
                        onTap: () => controller
                            .formatSelection(const SizeAttribute('small')),
                      ),
                      _FormatTile(
                        icon: Icons.text_increase,
                        title: l10n.sizeLarge,
                        subtitle: l10n.sizeLargeHint,
                        selected: _has(const SizeAttribute('large')),
                        colors: colors,
                        onTap: () => controller
                            .formatSelection(const SizeAttribute('large')),
                      ),
                      _FormatTile(
                        icon: Icons.title,
                        title: l10n.sizeHuge,
                        subtitle: l10n.sizeHugeHint,
                        selected: _has(const SizeAttribute('huge')),
                        colors: colors,
                        onTap: () => controller
                            .formatSelection(const SizeAttribute('huge')),
                      ),
                      _SectionTitle(title: l10n.sectionColor, colors: colors),
                      Padding(
                        padding: const EdgeInsets.only(bottom: 8),
                        child: Wrap(
                          spacing: 8,
                          runSpacing: 8,
                          children: [
                            for (final entry in colorEntries)
                              _ColorChip(
                                label: entry.key,
                                color: entry.value,
                                selected: _has(
                                  ColorAttribute(
                                    '#${entry.value.toARGB32().toRadixString(16).substring(2)}',
                                  ),
                                ),
                                colors: colors,
                                onTap: () {
                                  final hex =
                                      '#${entry.value.toARGB32().toRadixString(16).substring(2)}';
                                  controller.formatSelection(ColorAttribute(hex));
                                },
                              ),
                            ActionChip(
                              label: Text(l10n.colorDefault),
                              side: BorderSide(
                                color: colors.primary.withValues(alpha: 0.45),
                              ),
                              backgroundColor: colors.selected,
                              labelStyle: TextStyle(
                                color: colors.primary,
                                fontSize: 12,
                              ),
                              onPressed: () => _applyOrClear(
                                const ColorAttribute(null),
                                clear: true,
                              ),
                            ),
                          ],
                        ),
                      ),
                      _SectionTitle(title: l10n.sectionParagraph, colors: colors),
                      _FormatTile(
                        icon: Icons.format_quote,
                        title: l10n.quote,
                        subtitle: l10n.quoteHint,
                        selected: _has(Attribute.blockQuote),
                        colors: colors,
                        onTap: () => _toggle(Attribute.blockQuote),
                      ),
                      _FormatTile(
                        icon: Icons.format_list_bulleted,
                        title: l10n.bulletList,
                        subtitle: l10n.bulletListHint,
                        selected: _has(Attribute.ul),
                        colors: colors,
                        onTap: () => _toggle(Attribute.ul),
                      ),
                      _FormatTile(
                        icon: Icons.format_list_numbered,
                        title: l10n.numberedList,
                        subtitle: l10n.numberedListHint,
                        selected: _has(Attribute.ol),
                        colors: colors,
                        onTap: () => _toggle(Attribute.ol),
                      ),
                      _FormatTile(
                        icon: Icons.format_indent_increase,
                        title: l10n.indentMore,
                        subtitle: l10n.indentMoreHint,
                        colors: colors,
                        onTap: () => controller.indentSelection(true),
                      ),
                      _FormatTile(
                        icon: Icons.format_indent_decrease,
                        title: l10n.indentLess,
                        subtitle: l10n.indentLessHint,
                        colors: colors,
                        onTap: () => controller.indentSelection(false),
                      ),
                      _SectionTitle(title: l10n.sectionInsert, colors: colors),
                      _FormatTile(
                        icon: Icons.widgets_outlined,
                        title: l10n.copyBlock,
                        subtitle: l10n.copyBlockHint,
                        colors: colors,
                        onTap: onInsertSnippet,
                      ),
                      _FormatTile(
                        icon: Icons.image_outlined,
                        title: l10n.insertImage,
                        subtitle: l10n.insertImageHint,
                        colors: colors,
                        onTap: onInsertImage,
                      ),
                      _FormatTile(
                        icon: Icons.photo_size_select_large_outlined,
                        title: l10n.imageWidth,
                        subtitle: l10n.imageWidthHint,
                        colors: colors,
                        onTap: onResizeImage,
                      ),
                    ],
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _SectionTitle extends StatelessWidget {
  const _SectionTitle({required this.title, required this.colors});

  final String title;
  final AppThemeColors colors;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(4, 12, 4, 6),
      child: Text(
        title,
        style: TextStyle(
          fontSize: 12,
          fontWeight: FontWeight.w600,
          color: colors.textSecondary,
          letterSpacing: 0.4,
        ),
      ),
    );
  }
}

class _FormatTile extends StatelessWidget {
  const _FormatTile({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.colors,
    required this.onTap,
    this.selected = false,
  });

  final IconData icon;
  final String title;
  final String subtitle;
  final AppThemeColors colors;
  final VoidCallback? onTap;
  final bool selected;

  @override
  Widget build(BuildContext context) {
    final enabled = onTap != null;
    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: Material(
        color: selected ? colors.selected : colors.hover.withValues(alpha: 0.35),
        borderRadius: BorderRadius.circular(10),
        child: InkWell(
          borderRadius: BorderRadius.circular(10),
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
            child: Row(
              children: [
                Icon(
                  icon,
                  size: 22,
                  color: !enabled
                      ? colors.textSecondary.withValues(alpha: 0.4)
                      : selected
                          ? colors.primary
                          : colors.textPrimary,
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        title,
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                          color: !enabled
                              ? colors.textSecondary.withValues(alpha: 0.5)
                              : colors.textPrimary,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        subtitle,
                        style: TextStyle(
                          fontSize: 11,
                          color: colors.textSecondary,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _ColorChip extends StatelessWidget {
  const _ColorChip({
    required this.label,
    required this.color,
    required this.selected,
    required this.colors,
    required this.onTap,
  });

  final String label;
  final Color color;
  final bool selected;
  final AppThemeColors colors;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(16),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: selected ? colors.primary : colors.border,
            width: selected ? 1.5 : 1,
          ),
          color: selected ? colors.selected : colors.sidebar,
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 14,
              height: 14,
              decoration: BoxDecoration(
                color: color,
                shape: BoxShape.circle,
                border: Border.all(color: colors.border),
              ),
            ),
            const SizedBox(width: 6),
            Text(label, style: TextStyle(fontSize: 12, color: colors.textPrimary)),
          ],
        ),
      ),
    );
  }
}
