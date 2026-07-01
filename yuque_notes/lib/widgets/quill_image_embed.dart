import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_quill/flutter_quill.dart';

class QuillImageEmbedBuilder extends EmbedBuilder {
  const QuillImageEmbedBuilder();

  @override
  String get key => BlockEmbed.imageType;

  @override
  Widget build(BuildContext context, EmbedContext embedContext) {
    final url = embedContext.node.value.data as String;
    if (url.startsWith('data:image/')) {
      final comma = url.indexOf(',');
      if (comma > 0) {
        final bytes = base64Decode(url.substring(comma + 1));
        return Padding(
          padding: const EdgeInsets.symmetric(vertical: 8),
          child: Image.memory(bytes, fit: BoxFit.contain),
        );
      }
    }
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Image.network(url, fit: BoxFit.contain),
    );
  }
}