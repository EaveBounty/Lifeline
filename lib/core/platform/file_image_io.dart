/// 原生：直接用 Image.file（与既有行为一致）。
library;

import 'dart:io';

import 'package:flutter/material.dart';

/// 从本地 [File] 构建图片；[onError] 在加载失败时返回占位组件。
Widget fileImage(
  File file, {
  BoxFit fit = BoxFit.cover,
  Widget Function()? onError,
}) =>
    Image.file(
      file,
      fit: fit,
      errorBuilder: (_, __, ___) =>
          onError?.call() ?? const SizedBox.shrink(),
    );
