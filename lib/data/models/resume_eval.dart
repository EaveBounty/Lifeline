/// 定向简历「一体两面的多角度评估」结果模型。
///
/// 一面是**岗位适配诊断（针对性）**：[FitAnalysis]（硬性要求对照 / 缺漏 / 按
/// 录取概率边际效益排序的行动清单）；另一面是**客观质量评分（通用）**：
/// [ObjectiveScore]（不依赖具体岗位的维度分与总分）。
///
/// 评估既可由本地确定性启发式产出，也可由 LLM 产出；无论来源，
/// [ResumeEvaluation.fromJson] 一律按**不可信数据**宽松解析并夹紧取值范围，
/// 任何字段缺失都退化为安全默认值；同时兼容旧版（schema v1）扁平结构。
library;

/// 一个客观评估维度。
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

/// 硬性要求（主要来自目标岗位画像的证书/资格）及简历满足情况。
class HardRequirement {
  final String name;

  /// have | partial | missing | unclear。
  final String status;

  /// required | preferred。
  final String importance;
  final String evidence;
  final String note;

  const HardRequirement({
    required this.name,
    this.status = 'unclear',
    this.importance = 'required',
    this.evidence = '',
    this.note = '',
  });

  Map<String, dynamic> toJson() => {
        'name': name,
        'status': status,
        'importance': importance,
        'evidence': evidence,
        'note': note,
      };

  factory HardRequirement.fromJson(Map<String, dynamic> j) => HardRequirement(
        name: _str(j['name']),
        status: _status(j['status']),
        importance: _importance(j['importance']),
        evidence: _str(j['evidence']),
        note: _str(j['note']),
      );
}

/// 岗位适配缺漏项。
class FitMissingItem {
  final String item;

  /// cert | experience | skill | education | portfolio | other。
  final String category;

  /// required | preferred。
  final String importance;
  final String why;
  final String suggestion;

  const FitMissingItem({
    required this.item,
    this.category = 'other',
    this.importance = 'required',
    this.why = '',
    this.suggestion = '',
  });

  Map<String, dynamic> toJson() => {
        'item': item,
        'category': category,
        'importance': importance,
        'why': why,
        'suggestion': suggestion,
      };

  factory FitMissingItem.fromJson(Map<String, dynamic> j) => FitMissingItem(
        item: _str(j['item']),
        category: _fitCategory(j['category']),
        importance: _importance(j['importance']),
        why: _str(j['why']),
        suggestion: _str(j['suggestion']),
      );
}

/// 「提升录取概率」的行动项；priority=1 为边际效益最高。
class FitAction {
  final String action;

  /// cert | experience | skill | education | portfolio | other。
  final String category;

  /// 预估录取概率提升（0–100）。
  final int expectedGain;

  /// low | medium | high。
  final String effort;
  final String timeEstimate;

  /// 1 = 最高优先。
  final int priority;
  final String rationale;
  final List<String> resources;

  /// 用户是否已勾选完成（本地标记）。
  final bool done;

  const FitAction({
    required this.action,
    this.category = 'other',
    this.expectedGain = 0,
    this.effort = 'medium',
    this.timeEstimate = '',
    this.priority = 1,
    this.rationale = '',
    this.resources = const [],
    this.done = false,
  });

  Map<String, dynamic> toJson() => {
        'action': action,
        'category': category,
        'expected_gain': expectedGain,
        'effort': effort,
        'time_estimate': timeEstimate,
        'priority': priority,
        'rationale': rationale,
        'resources': resources,
        'done': done,
      };

  factory FitAction.fromJson(Map<String, dynamic> j) {
    final action = _str(j['action']);
    return FitAction(
      // 兼容旧版 recommendations.item。
      action: action.isEmpty ? _str(j['item']) : action,
      category: _fitCategory(j['category']),
      expectedGain: _score(j['expected_gain']),
      effort: _effort(j['effort']),
      timeEstimate: _str(j['time_estimate']),
      priority: _priority(j['priority']),
      rationale: _str(j['rationale']),
      resources: _strList(j['resources']),
      done: j['done'] == true,
    );
  }
}

/// 岗位适配诊断（分类一 · 针对性）。
class FitAnalysis {
  /// 0–100 岗位适配度。
  final int fitScore;
  final List<HardRequirement> hardRequirements;
  final List<FitMissingItem> missing;
  final List<FitAction> recommendations;
  final String summary;
  final String? roleProfileId;
  final String? roleName;

  const FitAnalysis({
    this.fitScore = 0,
    this.hardRequirements = const [],
    this.missing = const [],
    this.recommendations = const [],
    this.summary = '',
    this.roleProfileId,
    this.roleName,
  });

  Map<String, dynamic> toJson() => {
        'fit_score': fitScore,
        'hard_requirements': hardRequirements.map((e) => e.toJson()).toList(),
        'missing': missing.map((e) => e.toJson()).toList(),
        'recommendations': recommendations.map((e) => e.toJson()).toList(),
        'summary': summary,
        'role_profile_id': roleProfileId,
        'role_name': roleName,
      };

  factory FitAnalysis.fromJson(Map<String, dynamic> j) => FitAnalysis(
        fitScore: _score(j['fit_score']),
        hardRequirements:
            _mapList(j['hard_requirements'], HardRequirement.fromJson),
        missing: _mapList(j['missing'], FitMissingItem.fromJson),
        recommendations: _mapList(j['recommendations'], FitAction.fromJson),
        summary: _str(j['summary']),
        roleProfileId: _nullStr(j['role_profile_id']),
        roleName: _nullStr(j['role_name']),
      );

  FitAnalysis copyWith({
    int? fitScore,
    List<HardRequirement>? hardRequirements,
    List<FitMissingItem>? missing,
    List<FitAction>? recommendations,
    String? summary,
    String? roleProfileId,
    String? roleName,
  }) =>
      FitAnalysis(
        fitScore: fitScore ?? this.fitScore,
        hardRequirements: hardRequirements ?? this.hardRequirements,
        missing: missing ?? this.missing,
        recommendations: recommendations ?? this.recommendations,
        summary: summary ?? this.summary,
        roleProfileId: roleProfileId ?? this.roleProfileId,
        roleName: roleName ?? this.roleName,
      );
}

/// 客观质量评分（分类二 · 通用、不依赖具体岗位）。
class ObjectiveScore {
  /// 0–100 加权总分。
  final int overall;
  final List<EvalDimension> dimensions;
  final List<String> strengths;
  final List<String> weaknesses;
  final String summary;

  const ObjectiveScore({
    this.overall = 0,
    this.dimensions = const [],
    this.strengths = const [],
    this.weaknesses = const [],
    this.summary = '',
  });

  Map<String, dynamic> toJson() => {
        'overall': overall,
        'dimensions': dimensions.map((e) => e.toJson()).toList(),
        'strengths': strengths,
        'weaknesses': weaknesses,
        'summary': summary,
      };

  factory ObjectiveScore.fromJson(Map<String, dynamic> j) => ObjectiveScore(
        overall: _score(j['overall']),
        dimensions: _mapList(j['dimensions'], EvalDimension.fromJson),
        strengths: _strList(j['strengths']),
        weaknesses: _strList(j['weaknesses']),
        summary: _str(j['summary']),
      );

  ObjectiveScore copyWith({
    int? overall,
    List<EvalDimension>? dimensions,
    List<String>? strengths,
    List<String>? weaknesses,
    String? summary,
  }) =>
      ObjectiveScore(
        overall: overall ?? this.overall,
        dimensions: dimensions ?? this.dimensions,
        strengths: strengths ?? this.strengths,
        weaknesses: weaknesses ?? this.weaknesses,
        summary: summary ?? this.summary,
      );

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

/// 完整评估结果：一体两面。
class ResumeEvaluation {
  final FitAnalysis fit;
  final ObjectiveScore objective;
  final String? targetRole;
  final String? targetCompany;

  /// 是否由 AI 产出（false = 启发式）。
  final bool aiAssisted;
  final String? model;
  final DateTime generatedAt;
  final String schemaVersion;

  const ResumeEvaluation({
    this.fit = const FitAnalysis(),
    this.objective = const ObjectiveScore(),
    this.targetRole,
    this.targetCompany,
    this.aiAssisted = false,
    this.model,
    required this.generatedAt,
    this.schemaVersion = kEvalSchemaVersion,
  });

  /// 兼容旧调用的便捷读取（等同客观总分）。
  int get overall => objective.overall;

  /// 兼容旧调用的便捷读取（等同客观维度）。
  List<EvalDimension> get dimensions => objective.dimensions;

  ResumeEvaluation copyWith({
    FitAnalysis? fit,
    ObjectiveScore? objective,
    String? targetRole,
    String? targetCompany,
    bool? aiAssisted,
    String? model,
    DateTime? generatedAt,
    String? schemaVersion,
  }) =>
      ResumeEvaluation(
        fit: fit ?? this.fit,
        objective: objective ?? this.objective,
        targetRole: targetRole ?? this.targetRole,
        targetCompany: targetCompany ?? this.targetCompany,
        aiAssisted: aiAssisted ?? this.aiAssisted,
        model: model ?? this.model,
        generatedAt: generatedAt ?? this.generatedAt,
        schemaVersion: schemaVersion ?? this.schemaVersion,
      );

  Map<String, dynamic> toJson() => {
        'schema_version': schemaVersion,
        'fit': fit.toJson(),
        'objective': objective.toJson(),
        'target_role': targetRole,
        'target_company': targetCompany,
        'ai_assisted': aiAssisted,
        'model': model,
        'generated_at': generatedAt.toIso8601String(),
      };

  factory ResumeEvaluation.fromJson(Map<String, dynamic> j) {
    final objectiveMap = (j['objective'] as Map?)?.cast<String, dynamic>();
    final fitMap = (j['fit'] as Map?)?.cast<String, dynamic>();
    final hasNew = objectiveMap != null || fitMap != null;

    ObjectiveScore objective;
    FitAnalysis fit;
    if (hasNew) {
      objective = objectiveMap == null
          ? const ObjectiveScore()
          : ObjectiveScore.fromJson(objectiveMap);
      fit = fitMap == null ? const FitAnalysis() : FitAnalysis.fromJson(fitMap);
      // 新结构中若客观段为空但顶层仍带旧字段，做一次兜底映射。
      if (objective.dimensions.isEmpty && j['dimensions'] is List) {
        objective = ObjectiveScore(
          overall: _score(j['overall']),
          dimensions: _mapList(j['dimensions'], EvalDimension.fromJson),
          strengths: _strList(j['strengths']),
          weaknesses: _strList(j['weaknesses']),
          summary: _str(j['summary']),
        );
      }
    } else {
      // 旧版 schema v1：顶层 overall/dimensions + missing/recommendations。
      objective = ObjectiveScore(
        overall: _score(j['overall']),
        dimensions: _mapList(j['dimensions'], EvalDimension.fromJson),
        strengths: _strList(j['strengths']),
        weaknesses: _strList(j['weaknesses']),
        summary: _str(j['summary']),
      );
      fit = FitAnalysis(
        missing: _mapList(j['missing'], FitMissingItem.fromJson),
        recommendations: _mapList(j['recommendations'], FitAction.fromJson),
        summary: _str(j['summary']),
      );
    }

    return ResumeEvaluation(
      fit: fit,
      objective: objective,
      targetRole: _nullStr(j['target_role']),
      targetCompany: _nullStr(j['target_company']),
      aiAssisted: j['ai_assisted'] == true,
      model: _nullStr(j['model']),
      generatedAt: DateTime.tryParse('${j['generated_at']}') ?? DateTime.now(),
      schemaVersion: _str(j['schema_version']).isEmpty
          ? kEvalSchemaVersion
          : _str(j['schema_version']),
    );
  }
}

/// 客观维度中文标签（match 已改由 [FitAnalysis] 承担，不再列入）。
const Map<String, String> kDimensionLabels = {
  'completeness': '内容完整度',
  'impact': '量化成果',
  'structure': '结构可读性',
  'language': '语言专业度',
  'ats': 'ATS 友好度',
  'differentiation': '差异化亮点',
  'density': '篇幅信息密度',
};

/// 客观维度默认权重（和为 1）。
const Map<String, double> kDimensionWeights = {
  'completeness': 0.20,
  'impact': 0.20,
  'structure': 0.15,
  'language': 0.12,
  'ats': 0.15,
  'differentiation': 0.12,
  'density': 0.06,
};

/// 评估结果 schema 版本。
const String kEvalSchemaVersion = '2';

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

String _status(dynamic v) {
  final s = _str(v).toLowerCase();
  return (s == 'have' || s == 'partial' || s == 'missing' || s == 'unclear')
      ? s
      : 'unclear';
}

String _importance(dynamic v) {
  final s = _str(v).toLowerCase();
  return (s == 'required' || s == 'preferred') ? s : 'required';
}

String _fitCategory(dynamic v) {
  final s = _str(v).toLowerCase();
  const ok = {
    'cert',
    'experience',
    'skill',
    'education',
    'portfolio',
    'other',
  };
  return ok.contains(s) ? s : 'other';
}

int _priority(dynamic v) {
  final n = (v is num ? v.toInt() : int.tryParse('${v ?? ''}') ?? 1);
  return n < 1 ? 1 : n;
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

/// 保留供旧调用方引用（已并入 FitMissingItem，concept 保留）。
String severityOf(String v) => _severity(v);
