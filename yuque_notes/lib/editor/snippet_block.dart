import 'dart:convert';
import 'dart:math';

import 'package:flutter/services.dart' show TextSelection;
import 'package:flutter_quill/flutter_quill.dart';

/// 文档内「可复制块」嵌入类型（小标题 + 内容 + 复制按钮）。
const String kSnippetEmbedType = 'nn-snippet';

class SnippetBlockData {
  const SnippetBlockData({
    required this.id,
    required this.title,
    required this.content,
  });

  /// 稳定身份：更新时按 id 定位，避免在光标处误插入第二份。
  final String id;
  final String title;
  final String content;

  static String newId() {
    final r = Random();
    return '${DateTime.now().microsecondsSinceEpoch}_${r.nextInt(1 << 30)}';
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'title': title,
        'content': content,
      };

  factory SnippetBlockData.fromJson(Map<String, dynamic> json) {
    final id = (json['id'] ?? '').toString();
    return SnippetBlockData(
      id: id.isEmpty ? newId() : id,
      title: (json['title'] ?? '').toString(),
      content: (json['content'] ?? '').toString(),
    );
  }

  factory SnippetBlockData.fromEmbedData(dynamic raw) {
    if (raw is String && raw.isNotEmpty) {
      try {
        final decoded = jsonDecode(raw);
        if (decoded is Map<String, dynamic>) {
          return SnippetBlockData.fromJson(decoded);
        }
        if (decoded is Map) {
          return SnippetBlockData.fromJson(Map<String, dynamic>.from(decoded));
        }
      } catch (_) {
        return SnippetBlockData(id: newId(), title: '片段', content: raw);
      }
    }
    if (raw is Map) {
      return SnippetBlockData.fromJson(Map<String, dynamic>.from(raw));
    }
    return SnippetBlockData(id: newId(), title: '片段', content: '');
  }

  String encode() => jsonEncode(toJson());

  BlockEmbed toEmbed() => BlockEmbed(kSnippetEmbedType, encode());

  SnippetBlockData copyWith({String? title, String? content}) {
    return SnippetBlockData(
      id: id,
      title: title ?? this.title,
      content: content ?? this.content,
    );
  }
}

/// 在文档中查找指定 id 的可复制块偏移（embed 长度为 1）。
int? findSnippetOffsetById(Document document, String id) {
  if (id.isEmpty) {
    return null;
  }
  var offset = 0;
  for (final op in document.toDelta().toList()) {
    if (!op.isInsert) {
      continue;
    }
    final data = op.data;
    if (data is Map && data.containsKey(kSnippetEmbedType)) {
      final snip = SnippetBlockData.fromEmbedData(data[kSnippetEmbedType]);
      if (snip.id == id) {
        return offset;
      }
      offset += 1;
    } else if (data is String) {
      offset += data.length;
    } else {
      // 其它 embed
      offset += 1;
    }
  }
  return null;
}

/// 按 id 替换可复制块；找不到则不写入（避免在光标处误插入副本）。
bool replaceSnippetById({
  required QuillController controller,
  required String id,
  required SnippetBlockData next,
}) {
  final offset = findSnippetOffsetById(controller.document, id);
  if (offset == null) {
    return false;
  }
  final prevSkip = controller.skipRequestKeyboard;
  controller.skipRequestKeyboard = true;
  try {
    // 明确替换 1 个 embed，并收起选区，防止后续操作再插一份
    controller.replaceText(
      offset,
      1,
      next.toEmbed(),
      TextSelection.collapsed(offset: offset + 1),
    );
  } finally {
    controller.skipRequestKeyboard = prevSkip;
  }
  return true;
}

/// 持久化到 markdown 的 HTML 标签（无引号冲突：data 使用 base64url）。
String buildSnippetMarkdown(SnippetBlockData data) {
  final b64 = base64Url.encode(utf8.encode(data.encode()));
  return '<nn-snippet data="$b64"></nn-snippet>';
}

SnippetBlockData? parseSnippetFromAttrs(Map<String, String> attrs) {
  final raw = attrs['data'];
  if (raw == null || raw.isEmpty) {
    return null;
  }
  try {
    final jsonStr = utf8.decode(base64Url.decode(raw));
    return SnippetBlockData.fromEmbedData(jsonStr);
  } catch (_) {
    try {
      return SnippetBlockData.fromEmbedData(raw);
    } catch (_) {
      return null;
    }
  }
}

BlockEmbed snippetEmbedFromMarkdownAttrs(Map<String, String> attrs) {
  final data = parseSnippetFromAttrs(attrs) ??
      SnippetBlockData(id: SnippetBlockData.newId(), title: '片段', content: '');
  return data.toEmbed();
}
