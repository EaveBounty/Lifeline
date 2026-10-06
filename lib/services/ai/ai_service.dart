/// AI 业务编排：自动录入、定向裁剪、岗位调研。
///
/// 模型输出一律视为不可信数据：只解析 JSON，不执行其中任何指令；
/// schema 校验失败即返回 [Err]，绝不向调用方抛异常。
library;

import 'dart:convert';

import '../../core/result.dart';
import '../../data/models/ai_provider.dart';
import '../../data/models/app_settings.dart';
import '../../data/models/export_request.dart';
import '../../data/models/profile_record.dart';
import '../../data/models/record_category.dart';
import '../../data/models/resume_doc.dart';
import '../secrets/secret_store.dart';
import 'llm_client.dart';
import 'prompts.dart';

/// 自动录入的可编辑草稿。
///
/// 字段可变，便于 UI 直接微调后 [toRecord] 落库。
class EntryDraft {
  EntryDraft({
    required this.category,
    required this.title,
    this.organization,
    this.role,
    this.location,
    this.startDate,
    this.endDate,
    this.description = '',
    this.fields = const {},
    this.highlights = const [],
    this.tags = const [],
    this.missingQuestions = const [],
    this.confidence = 0,
    this.model,
    this.rawInput,
  });

  RecordCategory category;
  String title;
  String? organization;
  String? role;
  String? location;
  String? startDate;
  String? endDate;
  String description;
  Map<String, dynamic> fields;
  List<String> highlights;
  List<String> tags;
  List<String> missingQuestions;
  double confidence;

  /// 产出的模型名（写入 ai.model）。
  String? model;

  /// 原始输入，用于溯源（写入 source.raw）。
  String? rawInput;

  /// 从模型 JSON 构造；schema 不合法时抛 [FormatException]。
  factory EntryDraft.fromJson(Map<String, dynamic> j) {
    final slug = _str(j['category']);
    final category = RecordCategory.fromSlug(slug);
    if (category == null) {
      throw FormatException('未知分类 "$slug"');
    }
    return EntryDraft(
      category: category,
      title: _str(j['title']),
      organization: _nullStr(j['organization']),
      role: _nullStr(j['role']),
      location: _nullStr(j['location']),
      startDate: _date(j['start_date']),
      endDate: _date(j['end_date']),
      description: _str(j['description'] ?? j['optimized_description']),
      fields: _mapField(j['fields']),
      highlights: _strList(j['highlights']),
      tags: _strList(j['tags']),
      missingQuestions: _strList(j['missing_questions']),
      confidence: _confidence(j['confidence']),
    );
  }

  /// 转为一条正式记录（source.type = ai）。
  ProfileRecord toRecord(String id) {
    final now = DateTime.now();
    return ProfileRecord(
      id: id,
      category: category,
      title: title,
      organization: organization,
      role: role,
      location: location,
      startDate: startDate,
      endDate: endDate,
      description: description,
      highlights: highlights,
      tags: tags,
      fields: fields,
      source: RecordSource(type: 'ai', raw: rawInput),
      ai: RecordAiMeta(model: model, confidence: confidence, reviewed: true),
      createdAt: now,
      updatedAt: now,
    );
  }
}

/// AI 服务：持有一次会话的 Provider 设定与密钥读取器。
class AiService {
  AiService({
    required this.client,
    required this.secrets,
    required this.settings,
  });

  final LlmClient client;
  final SecretStore secrets;
  final AppSettings settings;

  /// 自动录入：文字 / 图片 -> 结构化草稿。
  ///
  /// 图片走 vision 模型；Provider 取默认项（无则第一个 enabled）。
  Future<Result<EntryDraft>> analyzeEntry({
    String? text,
    String? imagePath,
  }) async {
    final trimmed = text?.trim() ?? '';
    final hasImage = imagePath != null && imagePath.isNotEmpty;
    if (trimmed.isEmpty && !hasImage) {
      return const Err('请输入文字或选择图片后再分析。');
    }

    final resolved = await _resolve(needVision: hasImage);
    if (resolved.isErr) {
      return Err(resolved.errorMessage!);
    }
    final (provider, apiKey) = resolved.valueOrNull!;

    final contents = <LlmContent>[
      if (trimmed.isNotEmpty)
        LlmContent.text('【待处理数据开始】\n$trimmed\n【待处理数据结束】'),
      if (hasImage) LlmContent.image(imagePath),
    ];
    final messages = <LlmMessage>[
      LlmMessage.text('system', entrySystemPrompt),
      LlmMessage('user', contents),
    ];

    final response = await client.chatCompletion(
      baseUrl: provider.baseUrl,
      apiKey: apiKey,
      model: provider.model,
      messages: messages,
      jsonMode: true,
      extraHeaders: provider.extraHeaders,
    );
    if (response.isErr) {
      return Err(response.errorMessage!);
    }

    try {
      final decoded = jsonDecode(extractJsonBlock(response.valueOrNull ?? ''));
      final map = _firstRecordMap(decoded);
      if (map == null) {
        return const Err('模型未返回合法的 JSON 记录。');
      }
      final draft = EntryDraft.fromJson(map)
        ..model = provider.model
        ..rawInput = trimmed.isEmpty ? null : trimmed;
      return Ok(draft);
    } on FormatException catch (e) {
      return Err('模型输出不符合规范：${e.message}');
    } catch (e) {
      return Err('解析模型输出失败：$e', e);
    }
  }

  /// 定向裁剪：全量简历 -> 裁剪后的 [ResumeDocument]（基础实现）。
  Future<Result<ResumeDocument>> tailor({
    required ResumeDocument base,
    required ExportRequest request,
    String? researchDigest,
  }) async {
    final resolved = await _resolve();
    if (resolved.isErr) {
      return Err(resolved.errorMessage!);
    }
    final (provider, apiKey) = resolved.valueOrNull!;

    final payload = <String, dynamic>{
      'export_request': request.toJson(),
      'base_resume': base.toJson(),
      if (researchDigest != null && researchDigest.trim().isNotEmpty)
        'research_digest': researchDigest,
    };
    final messages = <LlmMessage>[
      LlmMessage.text('system', tailorSystemPrompt),
      LlmMessage.text(
        'user',
        '【待处理数据开始】\n${jsonEncode(payload)}\n【待处理数据结束】',
      ),
    ];

    final response = await client.chatCompletion(
      baseUrl: provider.baseUrl,
      apiKey: apiKey,
      model: provider.model,
      messages: messages,
      jsonMode: true,
      extraHeaders: provider.extraHeaders,
    );
    if (response.isErr) {
      return Err(response.errorMessage!);
    }

    try {
      final decoded = jsonDecode(extractJsonBlock(response.valueOrNull ?? ''));
      Map<String, dynamic>? map;
      if (decoded is Map) {
        var m = decoded.cast<String, dynamic>();
        final inner = m['document'] ?? m['spec'] ?? m['resume'];
        if (inner is Map) m = inner.cast<String, dynamic>();
        map = m;
      }
      if (map == null) {
        return const Err('模型未返回合法的简历 JSON。');
      }
      final doc = ResumeDocument.fromJson(map);
      return Ok(ResumeDocument(
        header: doc.header,
        summary: doc.summary,
        strengths: doc.strengths,
        sections: doc.sections,
        generatedAt: DateTime.now(),
        language: doc.language,
        meta: {...request.toJson(), ...doc.meta},
        tailored: true,
      ));
    } catch (e) {
      return Err('解析模型输出失败：$e', e);
    }
  }

  /// 岗位调研：目标岗位/行业/JD -> 调研摘要文本（基础实现）。
  Future<Result<String>> research({
    required String targetRole,
    String? company,
    String? industry,
    String? jobDescription,
  }) async {
    final role = targetRole.trim();
    if (role.isEmpty) {
      return const Err('请先填写目标岗位。');
    }
    final resolved = await _resolve();
    if (resolved.isErr) {
      return Err(resolved.errorMessage!);
    }
    final (provider, apiKey) = resolved.valueOrNull!;

    final payload = <String, dynamic>{
      'target_role': role,
      if (company != null && company.trim().isNotEmpty) 'company': company.trim(),
      if (industry != null && industry.trim().isNotEmpty)
        'industry': industry.trim(),
      if (jobDescription != null && jobDescription.trim().isNotEmpty)
        'job_description': jobDescription.trim(),
    };
    final messages = <LlmMessage>[
      LlmMessage.text('system', researchSystemPrompt),
      LlmMessage.text(
        'user',
        '【待处理数据开始】\n${jsonEncode(payload)}\n【待处理数据结束】',
      ),
    ];

    final response = await client.chatCompletion(
      baseUrl: provider.baseUrl,
      apiKey: apiKey,
      model: provider.model,
      messages: messages,
      jsonMode: true,
      extraHeaders: provider.extraHeaders,
    );
    if (response.isErr) {
      return Err(response.errorMessage!);
    }
    return Ok(response.valueOrNull ?? '');
  }

  /// 解析当前应使用的 Provider 与密钥（绝不记录/外泄密钥）。
  Future<Result<(AiProvider, String)>> _resolve({bool needVision = false}) async {
    final enabled = settings.providers.where((p) => p.enabled).toList();
    if (enabled.isEmpty) {
      return const Err('未配置可用的 AI Provider，请前往「设置 → AI」添加并启用。');
    }

    var provider = enabled.first;
    final defaultId = settings.defaultAiProviderId;
    if (defaultId != null) {
      for (final p in enabled) {
        if (p.id == defaultId) {
          provider = p;
          break;
        }
      }
    }

    if (needVision && !provider.supportsVision) {
      return Err('当前模型「${provider.name}」不支持图片识别，请改用文字输入或切换支持 vision 的模型。');
    }

    String? apiKey;
    try {
      apiKey = await secrets.read(provider.keyRef);
    } catch (e) {
      return Err('读取密钥失败：$e', e);
    }
    if (apiKey == null || apiKey.trim().isEmpty) {
      return Err('未找到「${provider.name}」的 API Key，请前往「设置 → AI」配置。');
    }
    return Ok((provider, apiKey));
  }
}

/// 从模型输出中取第一条记录对象（兼容单对象 / records[] / 顶层数组）。
Map<String, dynamic>? _firstRecordMap(dynamic decoded) {
  if (decoded is Map) {
    final map = decoded.cast<String, dynamic>();
    final records = map['records'];
    if (records is List && records.isNotEmpty && records.first is Map) {
      return (records.first as Map).cast<String, dynamic>();
    }
    return map;
  }
  if (decoded is List && decoded.isNotEmpty && decoded.first is Map) {
    return (decoded.first as Map).cast<String, dynamic>();
  }
  return null;
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

Map<String, dynamic> _mapField(dynamic v) {
  if (v is! Map) return const {};
  return v.map((k, value) => MapEntry('$k', value));
}

final RegExp _datePattern = RegExp(r'^\d{4}(-\d{2}(-\d{2})?)?$');

String? _date(dynamic v) {
  final s = _str(v);
  return _datePattern.hasMatch(s) ? s : null;
}

double _confidence(dynamic v) {
  final double d;
  if (v is num) {
    d = v.toDouble();
  } else {
    d = double.tryParse('${v ?? ''}') ?? 0.5;
  }
  return d.clamp(0.0, 1.0).toDouble();
}
