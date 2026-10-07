/// 定向裁剪「计划」：AI 先做取舍决策（不写正文），再据此改写。
///
/// 这是「选择/表达分离」的核心产物，可校验、可回放、可迁移。
/// 所有解析都做范围夹紧与容错，绝不因模型输出异常而崩溃。
library;

class PlanDecision {
  final String? sourceRecordId;
  final String? itemId;

  /// lead | keep | compress | delete
  final String decision;
  final double relevance; // 0..1
  final double impact; // 0..1
  final double priority; // 0..1，越大越靠前
  final int bulletCap; // 该条目最多保留几条 bullet
  final String verbClass; // L1..L5
  final String reason;

  const PlanDecision({
    this.sourceRecordId,
    this.itemId,
    required this.decision,
    this.relevance = 0,
    this.impact = 0,
    this.priority = 0,
    this.bulletCap = 2,
    this.verbClass = 'L3',
    this.reason = '',
  });

  bool get kept => decision != 'delete';

  Map<String, dynamic> toJson() => {
        'source_record_id': sourceRecordId,
        'item_id': itemId,
        'decision': decision,
        'relevance': relevance,
        'impact': impact,
        'priority': priority,
        'bullet_cap': bulletCap,
        'verb_class': verbClass,
        'reason': reason,
      };

  factory PlanDecision.fromJson(Map<String, dynamic> j) {
    final d = '${j['decision'] ?? 'keep'}';
    return PlanDecision(
      sourceRecordId: j['source_record_id'] as String?,
      itemId: j['item_id'] as String?,
      decision: const {'lead', 'keep', 'compress', 'delete'}.contains(d) ? d : 'keep',
      relevance: _d(j['relevance']),
      impact: _d(j['impact']),
      priority: _d(j['priority']),
      bulletCap: ((j['bullet_cap'] as num?)?.toInt() ?? 2).clamp(0, 5),
      verbClass: '${j['verb_class'] ?? 'L3'}',
      reason: '${j['reason'] ?? ''}',
    );
  }
}

class TailorPlan {
  final String role;
  final String level;
  final String track;
  final int pageLimit;

  /// 一句话主线（本轮简历要传达到的定位）。
  final String narrative;

  /// JD → 术语归一 / ATS 关键词。
  final List<String> atsKeywords;

  /// 逐条记录决策（含 delete = 淘汰，[reason] 记录理由）。
  final List<PlanDecision> decisions;

  /// 章节优先顺序（key 列表）。
  final List<String> sectionPriority;

  /// 预算行数（估算）。
  final int budgetLines;

  /// 需要达到的 JD 关键词覆盖率（0..1）。
  final double minCoverage;

  /// 影响关键事实的追问（缺信息时给出，UI 可让用户补充或跳过）。
  final List<String> openQuestions;

  const TailorPlan({
    this.role = '',
    this.level = 'mid',
    this.track = 'general',
    this.pageLimit = 1,
    this.narrative = '',
    this.atsKeywords = const [],
    this.decisions = const [],
    this.sectionPriority = const [],
    this.budgetLines = 46,
    this.minCoverage = 0.8,
    this.openQuestions = const [],
  });

  Map<String, dynamic> toJson() => {
        'role': role,
        'level': level,
        'track': track,
        'page_limit': pageLimit,
        'narrative': narrative,
        'ats_keywords': atsKeywords,
        'decisions': decisions.map((d) => d.toJson()).toList(),
        'section_priority': sectionPriority,
        'budget_lines': budgetLines,
        'min_coverage': minCoverage,
        'open_questions': openQuestions,
      };

  factory TailorPlan.fromJson(Map<String, dynamic> j) => TailorPlan(
        role: '${j['role'] ?? ''}',
        level: '${j['level'] ?? 'mid'}',
        track: '${j['track'] ?? 'general'}',
        pageLimit: (j['page_limit'] as num?)?.toInt() ?? 1,
        narrative: '${j['narrative'] ?? ''}',
        atsKeywords:
            (j['ats_keywords'] as List?)?.map((e) => '$e').toList() ?? const [],
        decisions: (j['decisions'] as List?)
                ?.whereType<Map>()
                .map((e) => PlanDecision.fromJson(e.cast<String, dynamic>()))
                .toList() ??
            const [],
        sectionPriority:
            (j['section_priority'] as List?)?.map((e) => '$e').toList() ?? const [],
        budgetLines: (j['budget_lines'] as num?)?.toInt() ?? 46,
        minCoverage: _d(j['min_coverage'], fallback: 0.8),
        openQuestions:
            (j['open_questions'] as List?)?.map((e) => '$e').toList() ?? const [],
      );

  /// 删除项（供审计/展示）。
  List<PlanDecision> get rejected =>
      decisions.where((d) => d.decision == 'delete').toList();
}

double _d(dynamic v, {double fallback = 0}) {
  if (v is num) return v.toDouble().clamp(0, 1).toDouble();
  if (v is String) {
    final p = double.tryParse(v);
    if (p != null) return p.clamp(0, 1).toDouble();
  }
  return fallback;
}
