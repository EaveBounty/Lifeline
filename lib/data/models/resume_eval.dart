/// 定向简历「多角度评估」结果模型。
///
/// 评估既可由本地确定性启发式产出，也可由 LLM 产出；
/// 无论来源，[fromJson] 一律按**不可信数据**宽松解析并夹紧取值范围，
/// 任何字段缺失都退化为安全默认值。
library;

/// 一个评估维度。
class EvalDimension {
  final String key;
  final String label;

  /// 0–100。
  final int score;
  final String comment;
  final List<String> evidence;

  const EvalDimension({
    required this.key,
    required this.label,
    required this.score,
    this.comment = '',
    this.evidence = const [],
  });

  Map<String, dynamic> toJson() => {
        'key': key,
        'label': label,
        'score': score,
        'comment': comment,
        'evidence': evidence,
      };

  factory EvalDimension.fromJson(Map<String, dynamic> j) {
    final key = _str(j['key']);
    final label = _str(j['label']);
    return EvalDimension(
      key: key,
      label: label.isEmpty ? (kDimensionLabels[key] ?? key) : label,
      score: _score(j['score']),
      comment: _str(j['comment']),
      evidence: _strList(j['evidence']),
    );
  }
}

/// 缺漏项。
class EvalMissingItem {
  final String item;
  final String why;
  final String suggestion;

  /// high | medium | low。
  final String severity;

  const EvalMissingItem({
    required this.item,
    this.why = '',
    this.suggestion = '',
    this.severity = 'medium',
  });

  Map<String, dynamic> toJson() => {
        'item': item,
        'why': why,
        'suggestion': suggestion,
        'severity': severity,
      };

  factory EvalMissingItem.fromJson(Map<String, dynamic> j) => EvalMissingItem(
        item: _str(j['item']),
        why: _str(j['why']),
        suggestion: _str(j['suggestion']),
        severity: _severity(j['severity']),
      );
}

/// 改进建议：按「边际效益」排序（priority=1 最高）。
class EvalRecommendation {
  final String item;

  /// 预估提升（0–100，分数量纲）。
  final int expectedGain;

  /// low | medium | high。
  final String effort;

  /// 1 = 最高优先。
  final int priority;
  final String rationale;

  const EvalRecommendation({
    required this.item,
    this.expectedGain = 0,
    this.effort = 'medium',
    this.priority = 1,
    this.rationale = '',
  });

  Map<String, dynamic> toJson() => {
        'item': item,
        'expected_gain': expectedGain,
        'effort': effort,
        'priority': priority,
        'rationale': rationale,
      };

  factory EvalRecommendation.fromJson(Map<String, dynamic> j) =>
      EvalRecommendation(
        item: _str(j['item']),
        expectedGain: _score(j['expected_gain']),
        effort: _effort(j['effort']),
        priority: (j['priority'] as num?)?.toInt() ?? 1,
        rationale: _str(j['rationale']),
      );
}

/// 完整评估结果。
class ResumeEvaluation {
  final int overall;
  final List<EvalDimension> dimensions;
  final List<EvalMissingItem> missing;
  final List<EvalRecommendation> recommendations;
  final String? targetRole;
  final String? targetCompany;
  final String summary;

  /// 是否由 AI 产出（false = 启发式）。
  final bool aiAssisted;
  final String? model;
  final DateTime generatedAt;
  final String schemaVersion;

  const ResumeEvaluation({
    required this.overall,
    this.dimensions = const [],
    this.missing = const [],
    this.recommendations = const [],
    this.targetRole,
    this.targetCompany,
    this.summary = '',
    this.aiAssisted = false,
    this.model,
    required this.generatedAt,
    this.schemaVersion = kEvalSchemaVersion,
  });

  ResumeEvaluation copyWith({
    int? overall,
    List<EvalDimension>? dimensions,
    List<EvalMissingItem>? missing,
    List<EvalRecommendation>? recommendations,
    String? targetRole,
    String? targetCompany,
    String? summary,
    bool? aiAssisted,
    String? model,
    DateTime? generatedAt,
    String? schemaVersion,
  }) =>
      ResumeEvaluation(
        overall: overall ?? this.overall,
        dimensions: dimensions ?? this.dimensions,
        missing: missing ?? this.missing,
        recommendations: recommendations ?? this.recommendations,
        targetRole: targetRole ?? this.targetRole,
        targetCompany: targetCompany ?? this.targetCompany,
        summary: summary ?? this.summary,
        aiAssisted: aiAssisted ?? this.aiAssisted,
        model: model ?? this.model,
        generatedAt: generatedAt ?? this.generatedAt,
        schemaVersion: schemaVersion ?? this.schemaVersion,
      );

  Map<String, dynamic> toJson() => {
        'schema_version': schemaVersion,
        'overall': overall,
        'dimensions': dimensions.map((d) => d.toJson()).toList(),
        'missing': missing.map((m) => m.toJson()).toList(),
        'recommendations': recommendations.map((r) => r.toJson()).toList(),
        'target_role': targetRole,
        'target_company': targetCompany,
        'summary': summary,
        'ai_assisted': aiAssisted,
        'model': model,
        'generated_at': generatedAt.toIso8601String(),
      };

  factory ResumeEvaluation.fromJson(Map<String, dynamic> j) {
    final overall = _score(j['overall']);
    return ResumeEvaluation(
      overall: overall,
      dimensions: _mapList(j['dimensions'], EvalDimension.fromJson),
      missing: _mapList(j['missing'], EvalMissingItem.fromJson),
      recommendations: _mapList(j['recommendations'], EvalRecommendation.fromJson),
      targetRole: _nullStr(j['target_role']),
      targetCompany: _nullStr(j['target_company']),
      summary: _str(j['summary']),
      aiAssisted: j['ai_assisted'] == true,
      model: _nullStr(j['model']),
      generatedAt: DateTime.tryParse('${j['generated_at']}') ?? DateTime.now(),
      schemaVersion: _str(j['schema_version']).isEmpty
          ? kEvalSchemaVersion
          : _str(j['schema_version']),
    );
  }

  /// 按默认权重（可覆盖）计算加权总分，缺失维度不计入分母。
  static int computeOverall(
    List<EvalDimension> dims, {
    Map<String, double> weights = kDimensionWeights,
  }) {
    var sum = 0.0;
    var wsum = 0.0;
    for (final d in dims) {
      final w = weights[d.key] ?? weights[d.label];
      if (w == null) continue;
      sum += d.score * w;
      wsum += w;
    }
    if (wsum <= 0) {
      if (dims.isEmpty) return 0;
      sum = dims.fold<double>(0, (a, d) => a + d.score);
      wsum = dims.length.toDouble();
    }
    return (sum / wsum).round().clamp(0, 100);
  }
}

/// 维度中文标签。
const Map<String, String> kDimensionLabels = {
  'match': '岗位匹配度',
  'completeness': '内容完整度',
  'impact': '量化成果',
  'structure': '结构可读性',
  'language': '语言专业度',
  'ats': 'ATS 友好度',
  'differentiation': '差异化亮点',
  'density': '篇幅信息密度',
};

/// 默认权重（和为 1）。
const Map<String, double> kDimensionWeights = {
  'match': 0.20,
  'impact': 0.15,
  'completeness': 0.15,
  'structure': 0.12,
  'language': 0.10,
  'ats': 0.13,
  'differentiation': 0.10,
  'density': 0.05,
};

/// 评估结果 schema 版本。
const String kEvalSchemaVersion = '1';

// --- 解析辅助（对不可信输入宽松、安全） ---

int _score(dynamic v) {
  final n = v is num ? v.toDouble() : double.tryParse('${v ?? ''}') ?? 0;
  if (n.isNaN) return 0;
  return n.round().clamp(0, 100);
}

String _str(dynamic v) => v == null ? '' : '$v'.trim();

String? _nullStr(dynamic v) {
  final s = _str(v);
  return s.isEmpty ? null : s;
}

List<String> _strList(dynamic v) {
  if (v is! List) return const [];
  return v.map((e) => '$e'.trim()).where((e) => e.isNotEmpty).toList();
}

String _severity(dynamic v) {
  final s = _str(v).toLowerCase();
  return (s == 'high' || s == 'medium' || s == 'low') ? s : 'medium';
}

String _effort(dynamic v) {
  final s = _str(v).toLowerCase();
  return (s == 'low' || s == 'medium' || s == 'high') ? s : 'medium';
}

List<T> _mapList<T>(dynamic v, T Function(Map<String, dynamic>) fromJson) {
  if (v is! List) return const [];
  final out = <T>[];
  for (final e in v) {
    if (e is Map) {
      try {
        out.add(fromJson(e.cast<String, dynamic>()));
      } catch (_) {
        // 跳过坏条目。
      }
    }
  }
  return out;
}
