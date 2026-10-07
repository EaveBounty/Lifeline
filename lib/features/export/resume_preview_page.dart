/// 简历 PDF 预览页：内嵌预览 + 分享 + 用系统应用打开。
library;

import 'package:flutter/material.dart';
import 'package:open_filex/open_filex.dart';
import 'package:path/path.dart' as p;
import 'package:printing/printing.dart';
import 'package:share_plus/share_plus.dart';

import '../../core/platform/io_platform.dart';

class ResumePreviewPage extends StatelessWidget {
  const ResumePreviewPage({super.key, required this.title, required this.file});

  final String title;
  final File file;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(title, overflow: TextOverflow.ellipsis),
        actions: [
          IconButton(
            tooltip: '分享',
            icon: const Icon(Icons.share_outlined),
            onPressed: () => shareFile(file, text: title),
          ),
          IconButton(
            tooltip: '用系统应用打开',
            icon: const Icon(Icons.open_in_new),
            onPressed: () => OpenFilex.open(file.path),
          ),
        ],
      ),
      body: PdfPreview(
        build: (format) async => file.readAsBytes(),
        pdfFileName: p.basename(file.path),
        canChangePageFormat: false,
        canChangeOrientation: false,
        canDebug: false,
        allowPrinting: true,
        allowSharing: true,
      ),
    );
  }
}

/// 用系统分享面板分享一个文件（跨平台；桌面端由 share_plus 处理）。
Future<void> shareFile(File file, {String? text}) async {
  try {
    await SharePlus.instance.share(
      ShareParams(
        files: [XFile(file.path)],
        text: text,
      ),
    );
  } catch (_) {
    // 分享失败时静默（上层可选择用系统应用打开）。
  }
}
