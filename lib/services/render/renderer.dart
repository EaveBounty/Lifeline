/// 渲染器抽象：所有格式（PDF/DOCX/MD）消费同一 ResumeDocument IR。
///
/// 约定：失败不抛异常，统一返回 [Result]；调用方可按注册表顺序优雅降级。
library;

import 'dart:io';

import '../../core/result.dart';
import '../../core/utils/file_utils.dart';
import '../../data/models/resume_doc.dart';

/// 单一格式的渲染器。
abstract class ResumeRenderer {
  /// 规范格式标识：pdf | docx | md。
  String get format;

  /// 文件扩展名（不含点）。
  String get extension;

  /// 渲染为字节；options 为格式相关参数（如 pageLimit / language）。
  Future<Result<List<int>>> render(
    ResumeDocument doc, {
    Map<String, dynamic> options = const {},
  });

  /// 默认实现：渲染后原子写文件；子类一般无需覆写。
  Future<Result<void>> renderToFile(
    ResumeDocument doc,
    String path, {
    Map<String, dynamic> options = const {},
  }) async {
    final r = await render(doc, options: options);
    if (r.isErr) return Err(r.errorMessage!);
    try {
      await writeBytesAtomic(path, r.valueOrNull!);
      return const Ok<void>(null);
    } catch (e) {
      return Err('写入文件失败($path): $e', e);
    }
  }
}

/// 供渲染器共享的纯文本工具。
class RenderText {
  const RenderText._();

  /// 是否包含 CJK/全角字符（用于字体能力判断）。
  static bool hasCjk(String text) {
    for (final rune in text.runes) {
      if ((rune >= 0x2E80 && rune <= 0x9FFF) || // CJK 部首/统一表意
          (rune >= 0xF900 && rune <= 0xFAFF) || // 兼容表意
          (rune >= 0xFF00 && rune <= 0xFFEF) || // 全角
          (rune >= 0x3000 && rune <= 0x303F)) {
        return true;
      }
    }
    return false;
  }

  /// 汇总文档全部可见文本（字体探测用）。
  static String allText(ResumeDocument doc) {
    final sb = StringBuffer();
    sb.write(doc.header.name);
    sb.write(doc.header.englishName ?? '');
    sb.write(doc.header.headline ?? '');
    sb.write(doc.summary ?? '');
    sb.writeAll(doc.strengths);
    for (final s in doc.sections) {
      sb.write(s.title);
      for (final i in s.items) {
        sb.write(i.title);
        sb.write(i.subtitle ?? '');
        sb.write(i.meta ?? '');
        sb.write(i.description ?? '');
        sb.writeAll(i.bullets);
        sb.writeAll(i.tags);
      }
    }
    return sb.toString();
  }

  /// 读取本地文件为字节；失败返回 null。
  static Future<List<int>?> readFile(String path) async {
    try {
      final f = File(path);
      if (!await f.exists()) return null;
      return await f.readAsBytes();
    } catch (_) {
      return null;
    }
  }
}
