import 'package:flutter/material.dart';
import 'package:flutter_quill/flutter_quill.dart';

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
                      '格式工具',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                        color: colors.textPrimary,
                      ),
                    ),
                  ),
                  IconButton(
                    key: const Key('mobile_format_panel_close'),
                    tooltip: '关闭',
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
                      _SectionTitle(title: '编辑', colors: colors),
                      _FormatTile(
                        icon: Icons.undo,
                        title: '撤销',
                        subtitle: '撤销上一步',
                        colors: colors,
                        onTap: controller.hasUndo ? controller.undo : null,
                      ),
                      _FormatTile(
                        icon: Icons.redo,
                        title: '重做',
                        subtitle: '恢复上一步',
                        colors: colors,
                        onTap: controller.hasRedo ? controller.redo : null,
                      ),
                      _SectionTitle(title: '文字样式', colors: colors),
                      _FormatTile(
                        icon: Icons.format_bold,
                        title: '粗体',
                        subtitle: '加粗选中文字',
                        selected: _has(Attribute.bold),
                        colors: colors,
                        onTap: () => _toggle(Attribute.bold),
                      ),
                      _FormatTile(
                        icon: Icons.format_italic,
                        title: '斜体',
                        subtitle: '倾斜选中文字',
                        selected: _has(Attribute.italic),
                        colors: colors,
                        onTap: () => _toggle(Attribute.italic),
                      ),
                      _FormatTile(
                        icon: Icons.format_underlined,
                        title: '下划线',
                        subtitle: '添加下划线',
                        selected: _has(Attribute.underline),
                        colors: colors,
                        onTap: () => _toggle(Attribute.underline),
                      ),
                      _FormatTile(
                        icon: Icons.strikethrough_s,
                        title: '删除线',
                        subtitle: '添加删除线',
                        selected: _has(Attribute.strikeThrough),
                        colors: colors,
                        onTap: () => _toggle(Attribute.strikeThrough),
                      ),
                      _FormatTile(
                        icon: Icons.format_clear,
                        title: '清除格式',
                        subtitle: '去掉文字样式',
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
                      _SectionTitle(title: '字号', colors: colors),
                      _FormatTile(
                        icon: Icons.text_fields,
                        title: '默认',
                        subtitle: '恢复默认字号',
                        selected: !_hasKey(Attribute.size.key),
                        colors: colors,
                        onTap: () => _applyOrClear(
                          const SizeAttribute(null),
                          clear: true,
                        ),
                      ),
                      _FormatTile(
                        icon: Icons.text_decrease,
                        title: '较小',
                        subtitle: '字号变小',
                        selected: _has(const SizeAttribute('small')),
                        colors: colors,
                        onTap: () =>
                            controller.formatSelection(const SizeAttribute('small')),
                      ),
                      _FormatTile(
                        icon: Icons.text_increase,
                        title: '较大',
                        subtitle: '字号变大',
                        selected: _has(const SizeAttribute('large')),
                        colors: colors,
                        onTap: () =>
                            controller.formatSelection(const SizeAttribute('large')),
                      ),
                      _FormatTile(
                        icon: Icons.title,
                        title: '特大',
                        subtitle: '字号最大',
                        selected: _has(const SizeAttribute('huge')),
                        colors: colors,
                        onTap: () =>
                            controller.formatSelection(const SizeAttribute('huge')),
                      ),
                      _SectionTitle(title: '文字颜色', colors: colors),
                      Padding(
                        padding: const EdgeInsets.only(bottom: 8),
                        child: Wrap(
                          spacing: 8,
                          runSpacing: 8,
                          children: [
                            for (final entry in _textColors.entries)
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
                              label: const Text('默认色'),
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
                      _SectionTitle(title: '段落', colors: colors),
                      _FormatTile(
                        icon: Icons.format_quote,
                        title: '引用',
                        subtitle: '引用段落',
                        selected: _has(Attribute.blockQuote),
                        colors: colors,
                        onTap: () => _toggle(Attribute.blockQuote),
                      ),
                      _FormatTile(
                        icon: Icons.format_list_bulleted,
                        title: '项目符号',
                        subtitle: '无序列表',
                        selected: _has(Attribute.ul),
                        colors: colors,
                        onTap: () => _toggle(Attribute.ul),
                      ),
                      _FormatTile(
                        icon: Icons.format_list_numbered,
                        title: '编号列表',
                        subtitle: '有序列表',
                        selected: _has(Attribute.ol),
                        colors: colors,
                        onTap: () => _toggle(Attribute.ol),
                      ),
                      _FormatTile(
                        icon: Icons.format_indent_increase,
                        title: '增加缩进',
                        subtitle: '段落向右缩进',
                        colors: colors,
                        onTap: () => controller.indentSelection(true),
                      ),
                      _FormatTile(
                        icon: Icons.format_indent_decrease,
                        title: '减少缩进',
                        subtitle: '段落向左缩进',
                        colors: colors,
                        onTap: () => controller.indentSelection(false),
                      ),
                      _SectionTitle(title: '插入', colors: colors),
                      _FormatTile(
                        icon: Icons.widgets_outlined,
                        title: '可复制块',
                        subtitle: '小标题+内容，可一键复制',
                        colors: colors,
                        onTap: onInsertSnippet,
                      ),
                      _FormatTile(
                        icon: Icons.image_outlined,
                        title: '插入图片',
                        subtitle: '从相册选择图片',
                        colors: colors,
                        onTap: onInsertImage,
                      ),
                      _FormatTile(
                        icon: Icons.photo_size_select_large_outlined,
                        title: '图片宽度',
                        subtitle: '调整选中图片宽度',
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

const Map<String, Color> _textColors = {
  '黑': Color(0xFF262626),
  '红': Color(0xFFE53935),
  '橙': Color(0xFFFB8C00),
  '绿': Color(0xFF00B96B),
  '蓝': Color(0xFF1E88E5),
  '紫': Color(0xFF8E24AA),
};

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
