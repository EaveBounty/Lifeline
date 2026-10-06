/// 附件展示复用组件：缩略图与预览（records / attachments 共享）。
///
/// 预览按类型分派：
/// - 图片：内联/可缩放；
/// - PDF：内页渲染（`printing` 的 `PdfPreview`）；
/// - 文本（txt/md/json/csv/yaml/xml/log）：内联文本；
/// - 其它：元信息 + 「用系统应用打开」（`open_filex`）。
/// 所有类型都可「用系统应用打开」。
library;

import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:open_filex/open_filex.dart';
import 'package:path/path.dart' as p;
import 'package:printing/printing.dart';

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

enum _Kind { image, pdf, text, other }

_Kind _classify(String relPath) {
  if (AttachmentTypes.isImage(relPath)) return _Kind.image;
  final ext = p.extension(relPath).toLowerCase().replaceFirst('.', '');
  if (ext == 'pdf') return _Kind.pdf;
  const textExts = {
    'txt', 'md', 'markdown', 'json', 'csv', 'log', 'yaml', 'yml', 'xml', 'ini',
  };
  if (textExts.contains(ext)) return _Kind.text;
  return _Kind.other;
}

IconData _iconFor(String relPath) => switch (_classify(relPath)) {
      _Kind.image => Icons.image_outlined,
      _Kind.pdf => Icons.picture_as_pdf_outlined,
      _Kind.text => Icons.description_outlined,
      _Kind.other => Icons.insert_drive_file_outlined,
    };

/// 附件缩略方块：图片显示缩略，其它显示对应类型图标 + 文件名。
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
        child: isImageAttachment(relPath)
            ? fileImage(
                file,
                fit: BoxFit.cover,
                onError: () => _ThumbFallback(name: attachmentName(relPath)),
              )
            : _ThumbFallback(
                name: attachmentName(relPath),
                icon: _iconFor(relPath),
              ),
      ),
    );
  }
}

class _ThumbFallback extends StatelessWidget {
  const _ThumbFallback({required this.name, this.icon = Icons.insert_drive_file_outlined});
  final String name;
  final IconData icon;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Container(
      color: scheme.surfaceContainerHighest,
      padding: const EdgeInsets.all(8),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(icon, size: 28, color: scheme.onSurfaceVariant),
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

/// 预览附件：按类型分派（图片/PDF/文本/其它）。
Future<void> showAttachmentPreview(
  BuildContext context, {
  required File file,
  required String relPath,
}) async {
  final name = attachmentName(relPath);
  switch (_classify(relPath)) {
    case _Kind.image:
      await _showImageDialog(context, file: file, name: name);
    case _Kind.pdf:
      await Navigator.of(context).push(
        MaterialPageRoute<void>(
          builder: (_) => _PdfPreviewPage(file: file, name: name),
        ),
      );
    case _Kind.text:
      await _showTextDialog(context, file: file, name: name);
    case _Kind.other:
      await _showOtherDialog(context, file: file, name: name);
  }
}

Future<void> _showImageDialog(
  BuildContext context, {
  required File file,
  required String name,
}) {
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
              _PreviewHeader(
                name: name,
                icon: Icons.image_outlined,
                onOpenExternal: () => _openExternal(ctx, file, name),
              ),
              const Divider(height: 1),
              Flexible(
                child: InteractiveViewer(
                  minScale: 0.5,
                  maxScale: 5,
                  child: fileImage(
                    file,
                    fit: BoxFit.contain,
                    onError: () => _MissingPreview(name: name),
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

Future<void> _showTextDialog(
  BuildContext context, {
  required File file,
  required String name,
}) async {
  String text;
  try {
    text = utf8.decode(await file.readAsBytes(), allowMalformed: true);
  } catch (e) {
    text = '（读取失败：$e）';
  }
  if (!context.mounted) return;
  await showDialog<void>(
    context: context,
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
              _PreviewHeader(
                name: name,
                icon: Icons.description_outlined,
                onOpenExternal: () => _openExternal(ctx, file, name),
              ),
              const Divider(height: 1),
              Flexible(
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: SingleChildScrollView(
                    child: SelectableText(
                      text,
                      style: const TextStyle(
                        fontFamily: 'monospace',
                        fontSize: 13,
                        height: 1.5,
                      ),
                    ),
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

Future<void> _showOtherDialog(
  BuildContext context, {
  required File file,
  required String name,
}) {
  return showDialog<void>(
    context: context,
    builder: (ctx) {
      final scheme = Theme.of(ctx).colorScheme;
      int? sizeBytes;
      try {
        if (file.existsSync()) sizeBytes = file.lengthSync();
      } catch (_) {}
      return AlertDialog(
        title: Text(name, overflow: TextOverflow.ellipsis),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(_iconFor(name), size: 64, color: scheme.onSurfaceVariant),
            const SizedBox(height: 12),
            const Text('此类型不支持内嵌预览，可用系统应用打开。',
                textAlign: TextAlign.center),
            if (sizeBytes != null)
              Padding(
                padding: const EdgeInsets.only(top: 8),
                child: Text('大小：${_fmtSize(sizeBytes)}',
                    style: TextStyle(color: scheme.onSurfaceVariant, fontSize: 12)),
              ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: const Text('关闭'),
          ),
          FilledButton.icon(
            onPressed: () => _openExternal(ctx, file, name),
            icon: const Icon(Icons.open_in_new),
            label: const Text('用系统应用打开'),
          ),
        ],
      );
    },
  );
}

class _PdfPreviewPage extends StatelessWidget {
  const _PdfPreviewPage({required this.file, required this.name});
  final File file;
  final String name;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(name, overflow: TextOverflow.ellipsis),
        actions: [
          IconButton(
            tooltip: '用系统应用打开',
            icon: const Icon(Icons.open_in_new),
            onPressed: () => _openExternal(context, file, name),
          ),
        ],
      ),
      body: PdfPreview(
        build: (format) async => Uint8List.fromList(await file.readAsBytes()),
        pdfFileName: name,
        canChangePageFormat: false,
        canChangeOrientation: false,
        canDebug: false,
        allowPrinting: true,
        allowSharing: true,
      ),
    );
  }
}

class _PreviewHeader extends StatelessWidget {
  const _PreviewHeader({
    required this.name,
    required this.icon,
    required this.onOpenExternal,
  });
  final String name;
  final IconData icon;
  final VoidCallback onOpenExternal;

  @override
  Widget build(BuildContext context) {
    return ListTile(
      leading: Icon(icon),
      title: Text(name, overflow: TextOverflow.ellipsis),
      trailing: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          IconButton(
            tooltip: '用系统应用打开',
            icon: const Icon(Icons.open_in_new),
            onPressed: onOpenExternal,
          ),
          IconButton(
            tooltip: '关闭',
            icon: const Icon(Icons.close),
            onPressed: () => Navigator.of(context).pop(),
          ),
        ],
      ),
    );
  }
}

Future<void> _openExternal(BuildContext context, File file, String name) async {
  final messenger = ScaffoldMessenger.of(context);
  if (kIsWeb) {
    messenger.showSnackBar(
      const SnackBar(content: Text('Web 端不支持用系统应用打开')),
    );
    return;
  }
  try {
    final result = await OpenFilex.open(file.path);
    if (result.type != ResultType.done && context.mounted) {
      messenger.showSnackBar(
        SnackBar(content: Text('无法打开：${result.message}')),
      );
    }
  } catch (e) {
    if (context.mounted) {
      messenger.showSnackBar(SnackBar(content: Text('打开失败：$e')));
    }
  }
}

String _fmtSize(int bytes) {
  if (bytes < 1024) return '$bytes B';
  if (bytes < 1024 * 1024) return '${(bytes / 1024).toStringAsFixed(1)} KB';
  return '${(bytes / 1024 / 1024).toStringAsFixed(1)} MB';
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
