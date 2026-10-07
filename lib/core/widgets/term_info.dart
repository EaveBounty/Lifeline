/// 专业名词的「大白话解释」：可点击弹出说明气泡，避免用户困惑。
library;

import 'package:flutter/material.dart';

/// 一个小问号图标；点击弹出 [plain]（+ 可选 [detail]）说明。
class InfoDot extends StatelessWidget {
  const InfoDot({super.key, required this.title, required this.plain, this.detail});

  final String title;
  final String plain;
  final String? detail;

  @override
  Widget build(BuildContext context) {
    return IconButton(
      visualDensity: VisualDensity.compact,
      tooltip: '什么是「$title」？',
      icon: Icon(Icons.help_outline,
          size: 16, color: Theme.of(context).colorScheme.outline),
      onPressed: () => showTermInfo(context, title, plain, detail),
    );
  }
}

/// 弹出名词解释。
Future<void> showTermInfo(
  BuildContext context,
  String title,
  String plain, [
  String? detail,
]) {
  return showDialog<void>(
    context: context,
    builder: (ctx) => AlertDialog(
      title: Text(title),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(plain, style: const TextStyle(height: 1.5)),
          if ((detail ?? '').trim().isNotEmpty) ...[
            const SizedBox(height: 8),
            Text(detail!.trim(),
                style: TextStyle(
                    height: 1.5,
                    fontSize: 12.5,
                    color: Theme.of(ctx).colorScheme.onSurfaceVariant)),
          ],
        ],
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(ctx),
          child: const Text('知道了'),
        ),
      ],
    ),
  );
}
