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
  final String extraNotes;

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
    this.extraNotes = '',
  });

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
        'extra_notes': extraNotes,
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
        extraNotes: (j['extra_notes'] ?? '') as String,
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

  /// 多角度评估结果（旧数据可能缺失）。
  final ResumeEvaluation? evaluation;

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
    this.evaluation,
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
    ResumeEvaluation? evaluation,
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
        evaluation: evaluation ?? this.evaluation,
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
        'evaluation': evaluation?.toJson(),
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
        evaluation: _parseEvaluation(j['evaluation']),
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
