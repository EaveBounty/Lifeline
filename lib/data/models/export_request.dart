/// 智能导出的输入问卷与产物元数据。
library;

import 'resume_eval.dart';

/// 导出问卷：明确用途、岗位、企业、要求。
class ExportRequest {
  final String purpose; // 求职/申请/投稿/内部汇报/其他
  final String targetRole;
  final String targetCompany;
  final String industry;
  final int pageLimit; // 0 = 不限
  final String language; // zh | en
  final String style; // concise | detailed | academic | creative
  final String tone; // professional | energetic | modest
  final String emphasis; // 用户希望突出什么
  final List<String> mustInclude;
  final List<String> exclude;
  final bool researchEnabled;

  /// 目标岗位 JD 原文（可选；用于深度岗位适配与裁剪）。
  final String jobDescription;

  /// 是否在简历后附「参考材料附录」并与正文交叉引用。
  final bool appendixEnabled;
  final String extraNotes;

  /// 简历模板 id（见 `services/render/templates.dart`）。
  final String templateId;

  /// 目标级别（校招/初/中/高/资深/管理）——用于级别校准。
  final String targetLevel;

  /// 职业阶段（在校/初期/中期/资深/管理/转行）。
  final String careerStage;

  /// 赛道（技术/金融/咨询/学术/央国企/设计/运营/通用）——用于权重与侧重。
  final String track;

  const ExportRequest({
    this.purpose = '求职',
    this.targetRole = '',
    this.targetCompany = '',
    this.industry = '',
    this.pageLimit = 1,
    this.language = 'zh',
    this.style = 'concise',
    this.tone = 'professional',
    this.emphasis = '',
    this.mustInclude = const [],
    this.exclude = const [],
    this.researchEnabled = true,
    this.jobDescription = '',
    this.appendixEnabled = false,
    this.extraNotes = '',
    this.templateId = 'ats-classic',
    this.targetLevel = 'mid',
    this.careerStage = 'early',
    this.track = 'general',
  });

  ExportRequest copyWith({
    String? purpose,
    String? targetRole,
    String? targetCompany,
    String? industry,
    int? pageLimit,
    String? language,
    String? style,
    String? tone,
    String? emphasis,
    List<String>? mustInclude,
    List<String>? exclude,
    bool? researchEnabled,
    String? jobDescription,
    bool? appendixEnabled,
    String? extraNotes,
    String? templateId,
    String? targetLevel,
    String? careerStage,
    String? track,
  }) =>
      ExportRequest(
        purpose: purpose ?? this.purpose,
        targetRole: targetRole ?? this.targetRole,
        targetCompany: targetCompany ?? this.targetCompany,
        industry: industry ?? this.industry,
        pageLimit: pageLimit ?? this.pageLimit,
        language: language ?? this.language,
        style: style ?? this.style,
        tone: tone ?? this.tone,
        emphasis: emphasis ?? this.emphasis,
        mustInclude: mustInclude ?? this.mustInclude,
        exclude: exclude ?? this.exclude,
        researchEnabled: researchEnabled ?? this.researchEnabled,
        jobDescription: jobDescription ?? this.jobDescription,
        appendixEnabled: appendixEnabled ?? this.appendixEnabled,
        extraNotes: extraNotes ?? this.extraNotes,
        templateId: templateId ?? this.templateId,
        targetLevel: targetLevel ?? this.targetLevel,
        careerStage: careerStage ?? this.careerStage,
        track: track ?? this.track,
      );

  Map<String, dynamic> toJson() => {
        'purpose': purpose,
        'target_role': targetRole,
        'target_company': targetCompany,
        'industry': industry,
        'page_limit': pageLimit,
        'language': language,
        'style': style,
        'tone': tone,
        'emphasis': emphasis,
        'must_include': mustInclude,
        'exclude': exclude,
        'research_enabled': researchEnabled,
        'job_description': jobDescription,
        'appendix_enabled': appendixEnabled,
        'extra_notes': extraNotes,
        'template_id': templateId,
        'target_level': targetLevel,
        'career_stage': careerStage,
        'track': track,
      };

  factory ExportRequest.fromJson(Map<String, dynamic> j) => ExportRequest(
        purpose: (j['purpose'] ?? '求职') as String,
        targetRole: (j['target_role'] ?? '') as String,
        targetCompany: (j['target_company'] ?? '') as String,
        industry: (j['industry'] ?? '') as String,
        pageLimit: (j['page_limit'] as num?)?.toInt() ?? 1,
        language: (j['language'] ?? 'zh') as String,
        style: (j['style'] ?? 'concise') as String,
        tone: (j['tone'] ?? 'professional') as String,
        emphasis: (j['emphasis'] ?? '') as String,
        mustInclude: (j['must_include'] as List?)?.map((e) => '$e').toList() ?? const [],
        exclude: (j['exclude'] as List?)?.map((e) => '$e').toList() ?? const [],
        researchEnabled: (j['research_enabled'] ?? true) as bool,
        jobDescription: (j['job_description'] ?? '') as String,
        appendixEnabled: (j['appendix_enabled'] ?? false) as bool,
        extraNotes: (j['extra_notes'] ?? '') as String,
        templateId: (j['template_id'] ?? 'ats-classic') as String,
        targetLevel: (j['target_level'] ?? 'mid') as String,
        careerStage: (j['career_stage'] ?? 'early') as String,
        track: (j['track'] ?? 'general') as String,
      );
}

/// 参考材料图文核对结果。
class MaterialCheck {
  final String label;
  final String verdict; // ok | weak | mismatch | no_material
  final String note;
  const MaterialCheck({required this.label, required this.verdict, this.note = ''});

  Map<String, dynamic> toJson() =>
      {'label': label, 'verdict': verdict, 'note': note};
  factory MaterialCheck.fromJson(Map<String, dynamic> j) => MaterialCheck(
        label: '${j['label'] ?? ''}',
        verdict: '${j['verdict'] ?? 'no_material'}',
        note: '${j['note'] ?? ''}',
      );
}

/// 定向简历管理元数据（`data/resumes/<id>/meta.json`）。
class ResumeMeta {
  /// schema 版本（B5）。
  final int schemaVersion;
  final String id;
  final String name;
  final String targetRole;
  final String targetCompany;
  final String purpose;

  /// 该简历的要求/约束摘要。
  final String requirements;

  /// pending | generating | generated | needs_regen | archived
  final String status;
  final Map<String, String> files; // format -> 相对路径
  final String? providerModel;
  final String? researchDigest;

  /// 生成该简历时使用的问卷（旧数据可能缺失）。
  final ExportRequest? request;

  /// 生成该简历时使用的模板 id（旧数据可能缺失）。
  final String? templateId;

  /// 多角度评估结果（旧数据可能缺失）。
  final ResumeEvaluation? evaluation;

  /// 评估/修订历史（最新在前；用于版本追溯）。
  final List<ResumeEvaluation> evalHistory;

  /// 参考材料图文核对结果（可选）。
  final List<MaterialCheck> materialChecks;

  final DateTime createdAt;
  final DateTime updatedAt;
  final String notes;

  const ResumeMeta({
    this.schemaVersion = 1,
    required this.id,
    required this.name,
    this.targetRole = '',
    this.targetCompany = '',
    this.purpose = '',
    this.requirements = '',
    this.status = 'pending',
    this.files = const {},
    this.providerModel,
    this.researchDigest,
    this.request,
    this.templateId,
    this.evaluation,
    this.evalHistory = const [],
    this.materialChecks = const [],
    required this.createdAt,
    required this.updatedAt,
    this.notes = '',
  });

  ResumeMeta copyWith({
    int? schemaVersion,
    String? name,
    String? targetRole,
    String? targetCompany,
    String? purpose,
    String? requirements,
    String? status,
    Map<String, String>? files,
    String? providerModel,
    String? researchDigest,
    ExportRequest? request,
    String? templateId,
    ResumeEvaluation? evaluation,
    List<ResumeEvaluation>? evalHistory,
    List<MaterialCheck>? materialChecks,
    DateTime? updatedAt,
    String? notes,
  }) =>
      ResumeMeta(
        schemaVersion: schemaVersion ?? this.schemaVersion,
        id: id,
        name: name ?? this.name,
        targetRole: targetRole ?? this.targetRole,
        targetCompany: targetCompany ?? this.targetCompany,
        purpose: purpose ?? this.purpose,
        requirements: requirements ?? this.requirements,
        status: status ?? this.status,
        files: files ?? this.files,
        providerModel: providerModel ?? this.providerModel,
        researchDigest: researchDigest ?? this.researchDigest,
        request: request ?? this.request,
        templateId: templateId ?? this.templateId,
        evaluation: evaluation ?? this.evaluation,
        evalHistory: evalHistory ?? this.evalHistory,
        materialChecks: materialChecks ?? this.materialChecks,
        createdAt: createdAt,
        updatedAt: updatedAt ?? DateTime.now(),
        notes: notes ?? this.notes,
      );

  Map<String, dynamic> toJson() => {
        'schema_version': schemaVersion,
        'id': id,
        'name': name,
        'target_role': targetRole,
        'target_company': targetCompany,
        'purpose': purpose,
        'requirements': requirements,
        'status': status,
        'files': files,
        'provider_model': providerModel,
        'research_digest': researchDigest,
        'request': request?.toJson(),
        'template_id': templateId,
        'evaluation': evaluation?.toJson(),
        'eval_history': evalHistory.map((e) => e.toJson()).toList(),
        'material_checks': materialChecks.map((m) => m.toJson()).toList(),
        'created_at': createdAt.toIso8601String(),
        'updated_at': updatedAt.toIso8601String(),
        'notes': notes,
      };

  factory ResumeMeta.fromJson(Map<String, dynamic> j) => ResumeMeta(
        schemaVersion: (j['schema_version'] as num?)?.toInt() ?? 1,
        id: (j['id'] ?? '') as String,
        name: (j['name'] ?? '') as String,
        targetRole: (j['target_role'] ?? '') as String,
        targetCompany: (j['target_company'] ?? '') as String,
        purpose: (j['purpose'] ?? '') as String,
        requirements: (j['requirements'] ?? '') as String,
        status: (j['status'] ?? 'pending') as String,
        files: (j['files'] as Map?)?.map((k, v) => MapEntry('$k', '$v')) ?? const {},
        providerModel: j['provider_model'] as String?,
        researchDigest: j['research_digest'] as String?,
        request: _parseRequest(j['request']),
        templateId: j['template_id'] as String?,
        evaluation: _parseEvaluation(j['evaluation']),
        evalHistory: (j['eval_history'] as List?)
                ?.map((e) => _parseEvaluation(e))
                .whereType<ResumeEvaluation>()
                .toList() ??
            const [],
        materialChecks: (j['material_checks'] as List?)
                ?.map((e) => MaterialCheck.fromJson((e as Map).cast<String, dynamic>()))
                .toList() ??
            const [],
        createdAt: DateTime.tryParse('${j['created_at']}') ?? DateTime.now(),
        updatedAt: DateTime.tryParse('${j['updated_at']}') ?? DateTime.now(),
        notes: (j['notes'] ?? '') as String,
      );
}

ExportRequest? _parseRequest(dynamic v) {
  if (v is! Map) return null;
  try {
    return ExportRequest.fromJson(v.cast<String, dynamic>());
  } catch (_) {
    return null;
  }
}

ResumeEvaluation? _parseEvaluation(dynamic v) {
  if (v is! Map) return null;
  try {
    return ResumeEvaluation.fromJson(v.cast<String, dynamic>());
  } catch (_) {
    return null;
  }
}
