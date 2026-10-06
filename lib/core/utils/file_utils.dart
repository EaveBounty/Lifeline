/// 文件工具：原子写、哈希、相对路径、目录与扩展名。
library;

import 'dart:convert';
import 'dart:io';

import 'package:crypto/crypto.dart';
import 'package:path/path.dart' as p;

/// 确保目录存在。
Future<void> ensureDir(String path) async {
  final dir = Directory(path);
  if (!await dir.exists()) {
    await dir.create(recursive: true);
  }
}

/// 原子写字节：同目录临时文件写完后 rename 覆盖。
///
/// 同目录保证 rename 在同一文件系统内，具备原子性。
Future<void> writeBytesAtomic(String path, List<int> bytes) async {
  final target = File(path);
  await ensureDir(target.parent.path);
  final tmp = File(
    '${target.path}.tmp-${DateTime.now().microsecondsSinceEpoch}',
  );
  await tmp.writeAsBytes(bytes, flush: true);
  await tmp.rename(target.path);
}

/// 原子写字符串（UTF-8）。
Future<void> writeStringAtomic(String path, String content) =>
    writeBytesAtomic(path, utf8.encode(content));

/// 原子写 JSON（UTF-8、缩进 2 空格）。
Future<void> writeJsonAtomic(String path, Object? data) => writeStringAtomic(
      path,
      const JsonEncoder.withIndent('  ').convert(data),
    );

/// 文件内容 sha1（十六进制）。
Future<String> sha1OfFile(String path) async {
  final bytes = await File(path).readAsBytes();
  return sha1OfBytes(bytes);
}

/// 字节内容 sha1（十六进制）。
String sha1OfBytes(List<int> bytes) => sha1.convert(bytes).toString();

/// 相对路径，统一使用 `/` 分隔。
String relativeTo(String root, String path) =>
    p.relative(path, from: root).replaceAll(r'\', '/');

/// 归一化绝对路径。
String normalizePath(String path) => p.normalize(p.absolute(path));

/// 小写扩展名（不含点）。
String extOf(String path) =>
    p.extension(path).replaceFirst('.', '').toLowerCase();
