/// 智能选图：按目标从照片库中加权挑选最合适的一张。
///
/// 权重构成（可解释、可复现）：证件照身份 > 分辨率 > 长宽比（接近 3:4）>
/// 时间新近 > 标签（正装/白底/蓝底 加分，生活照/休闲 减分）> 可选视觉模型分。
library;

import 'dart:math' as math;

import '../../data/models/photo.dart';

/// 选图上下文。
class PhotoCriteria {
  final String purpose; // 求职 / 申请 / 投稿 / 内部汇报 / 其他
  final String track; // academic / technical / ...
  final String careerStage;
  const PhotoCriteria({
    this.purpose = '求职',
    this.track = 'general',
    this.careerStage = 'early',
  });
}

/// 为一份简历挑选最合适的照片；无照片返回 null。
Photo? selectPhoto(List<Photo> photos, PhotoCriteria c) {
  if (photos.isEmpty) return null;
  final now = DateTime.now();
  Photo? best;
  var bestScore = double.negativeInfinity;
  for (final p in photos) {
    var s = 0.0;
    // 证件照优先：正式场合几乎必然用证件照。
    if (p.idPhoto) s += 40;
    // 分辨率（至多 32 分）。
    final px = (p.width ?? 0) * (p.height ?? 0);
    s += math.min(px / 1e6, 4) * 8;
    // 长宽比接近证件照 3:4（0.75），至多 15 分。
    final a = p.aspect;
    if (a != null) s += (1 - (a - 0.75).abs() / 0.75).clamp(0.0, 1.0) * 15;
    // 时间新近（3 年窗口，至多 12 分）。
    final t = p.takenAt ?? p.createdAt;
    final days = now.difference(t).inDays;
    s += (1 - (days / (365 * 3)).clamp(0.0, 1.0)) * 12;
    // 标签（中文/英文关键词）。
    final tags = p.tags.join(' ').toLowerCase();
    if (RegExp(r'证件照|正装|西装|白底|蓝底|红底|id photo|formal').hasMatch(tags)) {
      s += 8;
    }
    if (RegExp(r'生活照|休闲|自拍|旅游|casual').hasMatch(tags)) s -= 12;
    // 可选视觉模型分（0–1，至多 20 分）。
    if (p.aiScore != null) s += p.aiScore!.clamp(0.0, 1.0) * 20;
    if (s > bestScore) {
      bestScore = s;
      best = p;
    }
  }
  return best;
}

/// 最新的一张照片（按拍摄/文件时间，缺失回退创建时间）。
Photo? latestPhoto(List<Photo> photos) {
  if (photos.isEmpty) return null;
  DateTime when(Photo p) => p.takenAt ?? p.createdAt;
  return photos.reduce((a, b) => when(a).isAfter(when(b)) ? a : b);
}
