/// 附件展示复用组件：缩略图与全屏预览（records / attachments 共享）。
library;

import 'package:flutter/material.dart';
import 'package:path/path.dart' as p;

import '../../core/constants.dart';
import '../../core/platform/file_image.dart';
import '../../core/platform/io_platform.dart';
import '../../core/utils/path_guard.dart';

/// 相对路径 -> 绝对文件；越界（路径遍历）抛 [ArgumentError]。
File attachmentFileOf(String syncRoot, String relPath) {
  final abs = resolveWithinRoot(syncRoot, relPath);
  if (abs == null) {
    throw ArgumentError.value(relPath, 'relPath', '附件路径越界');
  }
  return File(abs);
}

/// 附件显示名（含扩展名）。
String attachmentName(String relPath) => p.basename(relPath);

/// 是否为图片附件。
bool isImageAttachment(String relPath) => AttachmentTypes.isImage(relPath);

/// 附件缩略方块：图片显示缩略，其它显示图标 + 文件名。
class AttachmentThumb extends StatelessWidget {
  const AttachmentThumb({
    super.key,
    required this.file,
    required this.relPath,
    this.size = 96,
    this.onTap,
  });

  final File file;
  final String relPath;
  final double size;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final isImage = isImageAttachment(relPath);
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(10),
      child: Container(
        width: size,
        height: size,
        decoration: BoxDecoration(
          border: Border.all(color: scheme.outlineVariant),
          borderRadius: BorderRadius.circular(10),
        ),
        clipBehavior: Clip.antiAlias,
        child: isImage
            ? fileImage(
                file,
                fit: BoxFit.cover,
                onError: () =>
                    _ThumbFallback(name: attachmentName(relPath)),
              )
            : _ThumbFallback(name: attachmentName(relPath)),
      ),
    );
  }
}

class _ThumbFallback extends StatelessWidget {
  const _ThumbFallback({required this.name});
  final String name;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Container(
      color: scheme.surfaceContainerHighest,
      padding: const EdgeInsets.all(8),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.insert_drive_file_outlined,
              size: 28, color: scheme.onSurfaceVariant),
          const SizedBox(height: 6),
          Text(
            name,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            textAlign: TextAlign.center,
            style: TextStyle(fontSize: 11, color: scheme.onSurfaceVariant),
          ),
        ],
      ),
    );
  }
}

/// 全屏 Dialog 预览：图片可缩放，其它显示图标与文件名。
Future<void> showAttachmentPreview(
  BuildContext context, {
  required File file,
  required String relPath,
}) {
  final isImage = isImageAttachment(relPath);
  final name = attachmentName(relPath);
  return showDialog<void>(
    context: context,
    barrierColor: Colors.black87,
    builder: (ctx) {
      final size = MediaQuery.of(ctx).size;
      final scheme = Theme.of(ctx).colorScheme;
      return Dialog(
        insetPadding: const EdgeInsets.all(24),
        backgroundColor: scheme.surface,
        child: ConstrainedBox(
          constraints: BoxConstraints(
            maxWidth: size.width * 0.92,
            maxHeight: size.height * 0.88,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              ListTile(
                leading: Icon(isImage
                    ? Icons.image_outlined
                    : Icons.insert_drive_file_outlined),
                title: Text(name, overflow: TextOverflow.ellipsis),
                trailing: IconButton(
                  tooltip: '关闭',
                  icon: const Icon(Icons.close),
                  onPressed: () => Navigator.of(ctx).pop(),
                ),
              ),
              const Divider(height: 1),
              Flexible(
                child: isImage
                    ? InteractiveViewer(
                        minScale: 0.5,
                        maxScale: 5,
                        child: fileImage(
                          file,
                          fit: BoxFit.contain,
                          onError: () => _MissingPreview(name: name),
                        ),
                      )
                    : Padding(
                        padding: const EdgeInsets.all(32),
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(Icons.insert_drive_file_outlined,
                                size: 72,
                                color: scheme.onSurfaceVariant),
                            const SizedBox(height: 16),
                            Text(name, textAlign: TextAlign.center),
                          ],
                        ),
                      ),
              ),
            ],
          ),
        ),
      );
    },
  );
}

class _MissingPreview extends StatelessWidget {
  const _MissingPreview({required this.name});
  final String name;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsets.all(32),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.broken_image_outlined,
              size: 72, color: scheme.onSurfaceVariant),
          const SizedBox(height: 16),
          Text('无法加载附件：$name', textAlign: TextAlign.center),
        ],
      ),
    );
  }
}
