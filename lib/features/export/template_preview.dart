/// 简历模板可视化缩略图：纯 Flutter 绘制，忠实反映各 layout 的版式差异。
///
/// 仅依赖 [ResumeTemplate.layout] / [ResumeTemplate.accentArgb]，不触碰数据层与渲染器。
library;

import 'package:flutter/material.dart';

import '../../services/render/templates.dart';

/// 纸张宽高比（竖版）。
const double _aspect = 1.32;

/// 模板缩略图：按 [ResumeTemplate.layout] 用 [CustomPaint] 绘制版式。
class TemplatePreview extends StatelessWidget {
  const TemplatePreview({
    super.key,
    required this.template,
    this.width = 220,
    this.showLabels = false,
  });

  /// 目标模板。
  final ResumeTemplate template;

  /// 缩略图宽度（高度按 [_aspect] 推导）。
  final double width;

  /// 是否在缩略图上标注 section 顺序。
  final bool showLabels;

  @override
  Widget build(BuildContext context) {
    final w = (width.isFinite && width > 0) ? width : 220.0;
    final h = w * _aspect;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return SizedBox(
      width: w,
      height: h,
      child: ClipRRect(
        borderRadius: BorderRadius.circular(w * 0.045),
        child: CustomPaint(
          size: Size(w, h),
          painter: _TemplatePainter(
            template: template,
            showLabels: showLabels,
            isDark: isDark,
          ),
        ),
      ),
    );
  }
}

/// 放大预览对话框：展示带 section 顺序标注的大图。
void showTemplatePreviewDialog(BuildContext context, ResumeTemplate template) {
  showDialog<void>(
    context: context,
    builder: (ctx) {
      final media = MediaQuery.of(ctx);
      final maxW = (media.size.width - 96).clamp(200.0, 420.0).toDouble();
      final maxH = (media.size.height - 200).clamp(300.0, 640.0).toDouble();
      var w = maxW;
      if (w * _aspect > maxH) w = maxH / _aspect;
      final text = Theme.of(ctx).textTheme;
      return AlertDialog(
        title: Text(template.name),
        content: SizedBox(
          width: w,
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Center(
                  child: TemplatePreview(
                    template: template,
                    width: w,
                    showLabels: true,
                  ),
                ),
                const SizedBox(height: 14),
                Text(template.description, style: text.bodyMedium),
                const SizedBox(height: 6),
                Text('适配：${template.bestFor.join(' / ')}', style: text.bodySmall),
                const SizedBox(height: 8),
                Wrap(
                  spacing: 6,
                  runSpacing: 4,
                  children: [
                    for (final tag in template.tags)
                      Chip(
                        label: Text(tag),
                        visualDensity: VisualDensity.compact,
                        materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                      ),
                  ],
                ),
              ],
            ),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('关闭'),
          ),
        ],
      );
    },
  );
}

/// 各 layout 的 section 顺序（用于缩略图标注）。
const Map<String, List<String>> _orders = {
  'single': ['姓名·联系', '摘要', '工作经历', '教育背景', '技能'],
  'two-column': ['左·联系', '左·技能', '右·经历', '右·项目', '教育'],
  'academic': ['居中标题', '论文/科研', '教育', '经历', '奖项'],
  'creative': ['装饰色块', '姓名', '作品集', '经历', '技能'],
  'compact': ['教育前置', '技能矩阵', '项目', '经历', '证书'],
  'elegant': ['姓名居中', '概述', '经历', '技能', '教育'],
  'mono': ['姓名', '经历', '教育', '技能'],
};

/// 圈码数字。
const List<String> _circles = ['①', '②', '③', '④', '⑤', '⑥', '⑦', '⑧', '⑨'];
String _circled(int i) => i < _circles.length ? _circles[i] : '${i + 1}.';

class _TemplatePainter extends CustomPainter {
  _TemplatePainter({
    required this.template,
    required this.showLabels,
    required this.isDark,
  });

  final ResumeTemplate template;
  final bool showLabels;
  final bool isDark;

  @override
  void paint(Canvas canvas, Size size) {
    final paper = isDark ? const Color(0xFF1B1E23) : Colors.white;
    final ink = isDark ? const Color(0xFFE8EAED) : const Color(0xFF23262B);
    final muted = isDark ? const Color(0xFF7C838C) : const Color(0xFFAAB0B8);
    final rule = isDark ? const Color(0xFF3A3F47) : const Color(0xFFDCE0E5);
    var accent = Color(template.accentArgb);
    if (isDark && accent.computeLuminance() < 0.22) {
      accent = Color.lerp(accent, Colors.white, 0.55)!;
    }
    if (template.layout == 'mono') accent = ink;

    // 纸张底 + 边框。
    canvas.drawRect(Offset.zero & size, Paint()..color = paper);
    canvas.drawRect(
      Offset.zero & size,
      Paint()
        ..color = rule
        ..style = PaintingStyle.stroke
        ..strokeWidth = size.width * 0.012,
    );

    final drawH = showLabels ? size.height * 0.74 : size.height;
    _Sketch(
      canvas: canvas,
      size: Size(size.width, drawH),
      ink: ink,
      muted: muted,
      accent: accent,
      rule: rule,
      layout: template.layout,
    ).paintLayout();

    if (showLabels) {
      _paintLabels(canvas, size, drawH, accent, muted);
    }
  }

  void _paintLabels(
    Canvas canvas,
    Size size,
    double drawH,
    Color accent,
    Color muted,
  ) {
    canvas.drawLine(
      Offset(size.width * 0.05, drawH),
      Offset(size.width * 0.95, drawH),
      Paint()
        ..color = accent.withValues(alpha: 0.5)
        ..strokeWidth = size.width * 0.006,
    );
    final order = _orders[template.layout] ?? _orders['single']!;
    final buf = StringBuffer();
    for (var i = 0; i < order.length; i++) {
      if (i > 0) buf.write('  ');
      buf.write('${_circled(i)}${order[i]}');
    }
    final tp = TextPainter(
      text: TextSpan(
        text: '顺序  ${buf.toString()}',
        style: TextStyle(
          color: muted,
          fontSize: (size.width * 0.055).clamp(5.5, 11.0),
          height: 1.5,
        ),
      ),
      textDirection: TextDirection.ltr,
      maxLines: 3,
      ellipsis: '…',
    )..layout(maxWidth: size.width * 0.9);
    tp.paint(canvas, Offset(size.width * 0.05, drawH + size.width * 0.035));
  }

  @override
  bool shouldRepaint(covariant _TemplatePainter old) =>
      old.template.id != template.id ||
      old.showLabels != showLabels ||
      old.isDark != isDark;
}

/// 绘制上下文：提供基础图元与各 layout 的画法。
class _Sketch {
  _Sketch({
    required this.canvas,
    required this.size,
    required this.ink,
    required this.muted,
    required this.accent,
    required this.rule,
    required this.layout,
  });

  final Canvas canvas;
  final Size size;
  final Color ink;
  final Color muted;
  final Color accent;
  final Color rule;
  final String layout;

  double get w => size.width;
  double get h => size.height;
  double get pad => w * 0.085;
  double get cw => w - pad * 2;

  Paint _fill(Color c) => Paint()..color = c;
  Paint _stroke(Color c, double t) => Paint()
    ..color = c
    ..style = PaintingStyle.stroke
    ..strokeWidth = t;

  /// 圆角实心块。
  void block(double x, double y, double bw, double bh, Color c, [double r = 2]) {
    canvas.drawRRect(
      RRect.fromRectAndRadius(Rect.fromLTWH(x, y, bw, bh), Radius.circular(r)),
      _fill(c),
    );
  }

  /// 文本占位线段。
  void bar(double x, double y, double bw, double bh, Color c) =>
      block(x, y, bw, bh, c, bh / 2);

  void line(double x1, double y1, double x2, double y2, Color c, double t) =>
      canvas.drawLine(Offset(x1, y1), Offset(x2, y2), _stroke(c, t));

  void dot(double x, double y, double r, Color c) =>
      canvas.drawCircle(Offset(x, y), r, _fill(c));

  void ring(double x, double y, double r, Color c, double t) =>
      canvas.drawCircle(Offset(x, y), r, _stroke(c, t));

  /// 段落占位线：末行缩短，制造文本感。
  void para(double x, double y, double maxW, int count, Color c, double lh) {
    for (var i = 0; i < count; i++) {
      final f = i == count - 1 ? 0.55 : (i.isOdd ? 0.9 : 1.0);
      bar(x, y + i * lh, maxW * f, lh * 0.34, c);
    }
  }

  void paintLayout() {
    switch (layout) {
      case 'two-column':
        _twoColumn();
        break;
      case 'academic':
        _academic();
        break;
      case 'creative':
        _creative();
        break;
      case 'compact':
        _compact();
        break;
      case 'elegant':
        _elegant();
        break;
      case 'mono':
        _mono();
        break;
      default:
        _single();
        break;
    }
  }

  /// 单列：顶部姓名/联系条 + 下划线小标题段落。
  void _single() {
    final x = pad;
    bar(x, h * 0.06, cw * 0.46, h * 0.05, ink);
    bar(x, h * 0.125, cw * 0.72, h * 0.016, muted);
    line(x, h * 0.175, x + cw, h * 0.175, accent, w * 0.008);
    var y = h * 0.215;
    for (var i = 0; i < 4; i++) {
      bar(x, y, cw * 0.3, h * 0.026, ink);
      line(x, y + h * 0.036, x + cw * 0.3, y + h * 0.036, accent, w * 0.005);
      para(x, y + h * 0.055, cw, 2, muted, h * 0.042);
      y += h * 0.185;
    }
  }

  /// 双栏：左窄栏(联系/技能) + 右宽栏(经历)，色块标题。
  void _twoColumn() {
    final lx = pad;
    final lw = cw * 0.32;
    final rx = pad + cw * 0.4;
    final rw = cw * 0.6;
    block(lx, h * 0.06, lw, h * 0.05, accent, w * 0.012);
    para(lx, h * 0.14, lw, 3, muted, h * 0.045);
    block(lx, h * 0.38, lw * 0.7, h * 0.03, ink, w * 0.008);
    for (var i = 0; i < 5; i++) {
      dot(lx + w * 0.014, h * 0.475 + i * h * 0.052, w * 0.012, accent);
      bar(lx + w * 0.038, h * 0.467 + i * h * 0.052, lw * 0.66, h * 0.014, muted);
    }
    block(rx, h * 0.06, rw * 0.72, h * 0.05, accent, w * 0.012);
    var y = h * 0.16;
    for (var i = 0; i < 3; i++) {
      bar(rx, y, rw * 0.5, h * 0.024, ink);
      para(rx, y + h * 0.045, rw, 2, muted, h * 0.042);
      line(rx, y + h * 0.135, rx + rw, y + h * 0.135, rule, w * 0.004);
      y += h * 0.175;
    }
  }

  /// 学术：居中标题 + 论文/科研前置 + 细分节线。
  void _academic() {
    final cx = w / 2;
    bar(cx - cw * 0.26, h * 0.055, cw * 0.52, h * 0.05, ink);
    bar(cx - cw * 0.18, h * 0.12, cw * 0.36, h * 0.016, muted);
    line(pad, h * 0.175, w - pad, h * 0.175, rule, w * 0.004);
    var y = h * 0.215;
    for (var i = 0; i < 4; i++) {
      final head = i < 2; // 前两节为论文/科研，强调色前置。
      bar(pad, y, cw * 0.34, h * 0.024, head ? accent : ink);
      if (head) {
        line(pad, y + h * 0.034, pad + cw * 0.34, y + h * 0.034, accent,
            w * 0.005);
      }
      para(pad, y + h * 0.05, cw, 2, muted, h * 0.04);
      y += h * 0.185;
    }
  }

  /// 创意：左侧整高色块 + 几何装饰，右侧内容。
  void _creative() {
    final panelX = w * 0.045;
    final panelW = w * 0.34;
    block(panelX, h * 0.05, panelW, h * 0.9, accent, w * 0.02);
    ring(panelX + panelW * 0.5, h * 0.2, w * 0.075,
        Colors.white.withValues(alpha: 0.75), w * 0.01);
    dot(panelX + panelW * 0.28, h * 0.42, w * 0.03,
        Colors.white.withValues(alpha: 0.45));
    block(panelX + panelW * 0.5, h * 0.54, w * 0.07, w * 0.07,
        Colors.white.withValues(alpha: 0.35), w * 0.012);
    bar(panelX + panelW * 0.2, h * 0.78, panelW * 0.6, h * 0.02,
        Colors.white.withValues(alpha: 0.8));

    final rx = panelX + panelW + w * 0.05;
    final rw = w - rx - pad * 0.6;
    bar(rx, h * 0.1, rw * 0.6, h * 0.045, ink);
    bar(rx, h * 0.165, rw * 0.8, h * 0.014, muted);
    var y = h * 0.24;
    for (var i = 0; i < 3; i++) {
      block(rx, y, w * 0.03, h * 0.026, accent, w * 0.006);
      bar(rx + w * 0.05, y, rw * 0.7, h * 0.024, ink);
      para(rx + w * 0.05, y + h * 0.042, rw * 0.95, 2, muted, h * 0.04);
      y += h * 0.17;
    }
  }

  /// 紧凑：技能矩阵小格 + 紧行距段落。
  void _compact() {
    final x = pad;
    bar(x, h * 0.05, cw * 0.42, h * 0.04, ink);
    bar(x, h * 0.105, cw * 0.7, h * 0.014, muted);
    const cols = 4;
    final gap = w * 0.015;
    final cellW = (cw - gap * (cols - 1)) / cols;
    final cellH = h * 0.035;
    var my = h * 0.16;
    for (var r = 0; r < 3; r++) {
      for (var c = 0; c < cols; c++) {
        final cx = x + c * (cellW + gap);
        final filled = (r + c) % 3 != 0;
        block(cx, my, cellW, cellH,
            filled ? accent.withValues(alpha: 0.22) : rule, w * 0.008);
        if (filled) {
          bar(cx + cellW * 0.18, my + cellH * 0.32, cellW * 0.64, cellH * 0.36,
              accent);
        }
      }
      my += cellH + gap;
    }
    var y = h * 0.36;
    for (var i = 0; i < 3; i++) {
      bar(x, y, cw * 0.3, h * 0.022, ink);
      para(x, y + h * 0.032, cw, 2, muted, h * 0.036);
      y += h * 0.155;
    }
  }

  /// 优雅：居中衬线感 + 两侧细线的居中标题。
  void _elegant() {
    final cx = w / 2;
    ring(cx, h * 0.11, w * 0.07, accent, w * 0.008);
    bar(cx - cw * 0.22, h * 0.22, cw * 0.44, h * 0.04, ink);
    bar(cx - cw * 0.14, h * 0.275, cw * 0.28, h * 0.014, muted);
    line(cx - cw * 0.18, h * 0.315, cx + cw * 0.18, h * 0.315, accent,
        w * 0.005);
    var y = h * 0.37;
    const widths = [0.74, 0.58];
    for (var i = 0; i < 3; i++) {
      bar(cx - cw * 0.12, y, cw * 0.24, h * 0.018, ink);
      line(pad, y + h * 0.009, cx - cw * 0.16, y + h * 0.009, rule, w * 0.004);
      line(cx + cw * 0.16, y + h * 0.009, w - pad, y + h * 0.009, rule,
          w * 0.004);
      for (var j = 0; j < widths.length; j++) {
        final ww = cw * widths[j];
        bar(cx - ww / 2, y + h * 0.04 + j * h * 0.035, ww, h * 0.013, muted);
      }
      y += h * 0.185;
    }
  }

  /// 极简单色：无装饰线，纯黑白层级。
  void _mono() {
    final x = pad;
    bar(x, h * 0.06, cw * 0.5, h * 0.05, ink);
    bar(x, h * 0.13, cw * 0.78, h * 0.016, muted);
    line(x, h * 0.18, x + cw, h * 0.18, ink, w * 0.006);
    var y = h * 0.225;
    for (var i = 0; i < 4; i++) {
      bar(x, y, cw * 0.32, h * 0.024, ink);
      line(x, y + h * 0.034, x + cw, y + h * 0.034, rule, w * 0.003);
      para(x, y + h * 0.05, cw, 2, muted, h * 0.042);
      y += h * 0.18;
    }
  }
}
