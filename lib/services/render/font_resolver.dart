/// CJK 字体探测：按「打包资源 → 系统字体」顺序解析可用 TrueType/OpenType。
///
/// 说明：`pdf` 包只支持单字体文件（ttf/otf），不支持 ttc 集合，故显式跳过
/// `.ttc`，避免解析崩溃。
library;

import 'dart:io';
import 'dart:typed_data';

import 'package:flutter/services.dart' show rootBundle;
import 'package:path/path.dart' as p;

/// 字体解析结果。
class ResolvedFont {
  const ResolvedFont(this.data, this.source, {this.cjkCapable = false});

  /// 字体字节；null 表示未找到。
  final ByteData? data;

  /// 来源描述（asset 路径或系统绝对路径）。
  final String? source;

  /// 是否具备 CJK 字形能力（仅为启发式标记）。
  final bool cjkCapable;

  bool get found => data != null;

  static const ResolvedFont none = ResolvedFont(null, null);
}

class FontResolver {
  FontResolver();

  /// 打包资源候选（需 pubspec 声明 assets/fonts/）。
  ///
  /// B1：`DroidSansFallbackFull.ttf`（Apache-2.0）随包分发，作为 CJK 兜底，
  /// 保证中文 PDF 不缺字。
  static const List<String> _bundled = [
    'assets/fonts/DroidSansFallbackFull.ttf',
    'assets/fonts/NotoSansCJKsc-Regular.otf',
    'assets/fonts/NotoSansSC-Regular.otf',
    'assets/fonts/NotoSansSC-Regular.ttf',
    'assets/fonts/SourceHanSansSC-Regular.otf',
    'assets/fonts/NotoSansCJK-Regular.ttf',
  ];

  /// 解析 CJK 字体；未找到返回 [ResolvedFont.none]。
  Future<ResolvedFont> resolveCjk() async {
    for (final asset in _bundled) {
      try {
        final data = await rootBundle.load(asset);
        if (_usable(data)) {
          return ResolvedFont(data, 'asset:$asset', cjkCapable: true);
        }
      } catch (_) {
        // 未声明/不存在，继续。
      }
    }

    for (final path in _systemCandidates()) {
      final bytes = await _readFontFile(path);
      if (bytes == null) continue;
      final data = ByteData.view(bytes.buffer, bytes.offsetInBytes, bytes.length);
      if (_usable(data)) {
        return ResolvedFont(data, path, cjkCapable: true);
      }
    }
    return ResolvedFont.none;
  }

  /// 单个候选路径读取为 Uint8List（避免 ByteData 视图偏移问题）。
  Future<Uint8List?> _readFontFile(String path) async {
    try {
      final f = File(path);
      if (!await f.exists()) return null;
      return await f.readAsBytes();
    } catch (_) {
      return null;
    }
  }

  /// 校验：非 ttc 集合、非空。
  bool _usable(ByteData d) {
    if (d.lengthInBytes < 12) return false;
    final tagBytes = d.buffer
        .asUint8List(d.offsetInBytes, 4)
        .map((b) => String.fromCharCode(b))
        .join();
    // 'ttcf' = TrueType Collection，pdf 包不支持。
    if (tagBytes == 'ttcf') return false;
    // 常见合法 sfnt 版本：0x00010000, 'OTTO', 'true', 'typ1'。
    final v = d.getUint32(0);
    return v == 0x00010000 ||
        tagBytes == 'OTTO' ||
        tagBytes == 'true' ||
        tagBytes == 'typ1';
  }

  /// 系统字体候选：按平台优先返回可用的单字体文件。
  List<String> _systemCandidates() {
    if (Platform.isAndroid) {
      return const [
        '/system/fonts/DroidSansFallbackFull.ttf',
        '/system/fonts/DroidSansFallback.ttf',
        '/system/fonts/NotoSansSC-Regular.otf',
        '/system/fonts/NotoSansCJK-Regular.ttf',
      ];
    }
    if (Platform.isWindows) {
      return const [
        'C:/Windows/Fonts/msyh.ttf',
        'C:/Windows/Fonts/simhei.ttf',
        'C:/Windows/Fonts/Deng.ttf',
        'C:/Windows/Fonts/simkai.ttf',
        'C:/Windows/Fonts/simfang.ttf',
      ];
    }
    if (Platform.isMacOS) {
      return const [
        '/Library/Fonts/Arial Unicode.ttf',
        '/System/Library/Fonts/Supplemental/Songti.ttc',
        '/System/Library/Fonts/PingFang.ttc',
      ];
    }
    // Linux：扫描常见字体目录，优先 Noto/Source Han/文泉驿/Droid。
    return _scanLinuxFonts();
  }

  List<String> _scanLinuxFonts() {
    final roots = <String>[
      '/usr/share/fonts',
      '/usr/local/share/fonts',
      '/usr/share/fonts/truetype',
      p.join(Platform.environment['HOME'] ?? '', '.fonts'),
      p.join(Platform.environment['HOME'] ?? '', '.local/share/fonts'),
    ];
    final hits = <String>[];
    for (final root in roots) {
      final dir = Directory(root);
      if (!root.contains('/') || !dir.existsSync()) continue;
      try {
        for (final entity in dir.listSync(recursive: true, followLinks: false)) {
          if (entity is! File) continue;
          final lower = entity.path.toLowerCase();
          if (lower.endsWith('.ttc')) continue;
          if (!(lower.endsWith('.ttf') || lower.endsWith('.otf'))) continue;
          final name = p.basename(lower);
          if (name.contains('cjk') ||
              name.contains('notosanssc') ||
              name.contains('sourcehan') ||
              name.contains('wqy') ||
              name.contains('droid') ||
              name.contains('unifont')) {
            hits.add(entity.path);
          }
        }
      } catch (_) {
        // 忽略不可读目录。
      }
    }
    // 稳定排序，保证可复现。
    hits.sort();
    return hits;
  }
}
