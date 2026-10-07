/// 简历 PDF 字体集：按版式选择「无衬线 / 衬线」，内嵌子集化的中英双字体。
///
/// 打包字体（OFL）：
/// - NotoSansSC-Regular/Bold、NotoSerifSC-Regular/Bold：中英混排主字体（含拉丁）；
/// - DroidSansFallbackFull：极生僻字兜底（子集未覆盖时）。
///
/// 加载失败时回退 `pw.Font.helvetica()`，保证渲染不崩（但中文可能缺字）。
library;

import 'package:flutter/services.dart' show rootBundle;
import 'package:pdf/widgets.dart' as pw;

class ResumeFonts {
  const ResumeFonts({
    required this.regular,
    required this.bold,
    this.fallback = const [],
    required this.source,
  });

  final pw.Font regular;
  final pw.Font bold;
  final List<pw.Font> fallback;

  /// 来源说明（供提示）。
  final String source;

  bool get embedded => source != 'helvetica';
}

class ResumeFontLoader {
  static const String _sans = 'NotoSansSC';
  static const String _serif = 'NotoSerifSC';
  static const String _droid = 'assets/fonts/DroidSansFallbackFull.ttf';

  /// 加载一套字体；[serif] 决定衬线与否。
  Future<ResumeFonts> load({required bool serif}) async {
    final fam = serif ? _serif : _sans;
    final reg = await _tryTtf('assets/fonts/$fam-Regular.ttf');
    final bld = await _tryTtf('assets/fonts/$fam-Bold.ttf');
    final fallback = <pw.Font>[];
    if (serif) {
      final alt = await _tryTtf('assets/fonts/$_sans-Regular.ttf');
      if (alt != null) fallback.add(alt);
    }
    final droid = await _tryTtf(_droid);
    if (droid != null) fallback.add(droid);

    if (reg == null) {
      return ResumeFonts(
        regular: pw.Font.helvetica(),
        bold: pw.Font.helveticaBold(),
        source: 'helvetica',
      );
    }
    return ResumeFonts(
      regular: reg,
      bold: bld ?? reg,
      fallback: fallback,
      source: 'asset:$fam',
    );
  }

  Future<pw.Font?> _tryTtf(String asset) async {
    try {
      final data = await rootBundle.load(asset);
      if (data.lengthInBytes < 12) return null;
      final tag = String.fromCharCodes(
        data.buffer.asUint8List(data.offsetInBytes, 4),
      );
      if (tag == 'ttcf') return null; // 集合字体不受支持
      return pw.Font.ttf(data);
    } catch (_) {
      return null;
    }
  }
}
