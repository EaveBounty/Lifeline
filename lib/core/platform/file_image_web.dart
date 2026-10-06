/// Web：Image.file 不受支持，改用内存字节的 Image.memory。
library;

import 'dart:typed_data';

import 'package:flutter/material.dart';

import 'io_platform.dart';

/// 从内存文件系统 [File] 读取字节构建图片。
Widget fileImage(
  File file, {
  BoxFit fit = BoxFit.cover,
  Widget Function()? onError,
}) =>
    FutureBuilder<Uint8List?>(
      future: _read(file),
      builder: (context, snap) {
        if (snap.connectionState != ConnectionState.done) {
          return const SizedBox.shrink();
        }
        final bytes = snap.data;
        if (bytes != null && bytes.isNotEmpty) {
          return Image.memory(bytes, fit: fit);
        }
        return onError?.call() ?? const SizedBox.shrink();
      },
    );

Future<Uint8List?> _read(File file) async {
  try {
    if (!await file.exists()) return null;
    return Uint8List.fromList(await file.readAsBytes());
  } catch (_) {
    return null;
  }
}
