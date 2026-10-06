/// 定向简历多角度评估服务。
///
/// - [evaluateHeuristic]：纯本地、确定性、离线可用的启发式评估。
/// - [evaluateWithAi]：调用 LLM 评估；模型输出按**不可信数据**解析，
///   解析失败返回 [Err]，调用方回退启发式结果。
library;

import 'dart:convert';
import 'dart:math' as math;

import '../../core/result.dart';
import '../../data/models/export_request.dart';
import '../../data/models/resume_doc.dart';
import '../../data/models/resume_eval.dart';
import '../ai/llm_client.dart';
import '../ai/prompts.dart';

class ResumeEvalService {
  ResumeEvalService({required this.llm});

  final LlmClient llm;

  // --- 启发式 ---

  /// 本地确定性评估；不联网、不读写文件。
  ResumeEvaluation evaluateHeuristic({
    required ResumeDocument doc,
    required ExportRequest request,
    DateTime? now,
  }) {
    final bullets = _allBullets(doc);
    final itemTexts = _itemTexts(doc);
    final fullText = _docText(doc);
    final chars = _charCount(fullText);

    final hasEdu = _hasSection(doc, const ['education', '教育', '学历', '学校', 'academic']);
    final hasExp = _hasSection(doc, const ['experience', '工作', '实习', '经历', 'employment']);
    final hasSkills = _hasSection(doc, const ['skill', '技能', '能力', '专长', '技术栈']);
    final hasContact = doc.header.contacts.isNotEmpty;
    final hasSummary = (doc.summary ?? '').trim().isNotEmpty;
    final totalItems = doc.sections.fold<int>(0, (a, s) => a + s.items.length);

    final targetKeywords = _keywordsFrom([
      request.targetRole,
      request.targetCompany,
      request.emphasis,
      ...request.mustInclude,
    ]);
    final atsKeywords = _keywordsFrom([
      request.targetRole,
      request.targetCompany,
      request.industry,
      request.emphasis,
      ...request.mustInclude,
    ]);

    // 1) 岗位匹配度。
    final matchScore = _matchScore(doc, targetKeywords, itemTexts);

    // 2) 内容完整度。
    var hits = 0;
    if (hasContact) hits++;
    if (hasEdu) hits++;
    if (hasExp) hits++;
    if (hasSkills) hits++;
    var completenessScore = (hits / 4 * 100).round();
    if (hasSummary) completenessScore = math.min(100, completenessScore + 8);
    if (totalItems == 0) completenessScore = math.min(completenessScore, 20);

    // 3) 量化成果。
    final impactScore = _impactScore(bullets, doc, itemTexts);

    // 4) 结构可读性。
    final structureScore = _structureScore(doc, totalItems, hasSummary);

    // 5) 语言专业度。
    final languageScore = _languageScore(bullets, itemTexts, hasSummary, doc.summary);

    // 6) ATS 友好度。
    final atsScore = _atsScore(doc, atsKeywords);

    // 7) 差异化亮点。
    final differentiationScore = _differentiationScore(doc);

    // 8) 篇幅信息密度。
    final densityScore = _densityScore(chars, request.pageLimit);

    final dimensions = <EvalDimension>[
      EvalDimension(
        key: 'match',
        label: kDimensionLabels['match']!,
        score: matchScore,
        comment: targetKeywords.isEmpty
            ? '未提供目标岗位，无法精确衡量匹配度，给中性分。'
            : '目标岗位关键词覆盖度约 $matchScore%。',
        evidence: _evidenceKeywords(doc, targetKeywords, itemTexts),
      ),
      EvalDimension(
        key: 'completeness',
        label: kDimensionLabels['completeness']!,
        score: completenessScore,
        comment: '必备项命中 $hits/4（联系方式/教育/经历/技能），共 $totalItems 个条目。',
        evidence: [
          if (hasContact) '含联系方式',
          if (hasEdu) '含教育经历',
          if (hasExp) '含工作/实习经历',
          if (hasSkills) '含技能',
          if (hasSummary) '含个人简介',
        ],
      ),
      EvalDimension(
        key: 'impact',
        label: kDimensionLabels['impact']!,
        score: impactScore,
        comment: '量化条目占比约 $impactScore%（含数字/百分比/金额/倍数等）。',
        evidence: _evidenceQuant(bullets),
      ),
      EvalDimension(
        key: 'structure',
        label: kDimensionLabels['structure']!,
        score: structureScore,
        comment: '${doc.sections.length} 个章节 / $totalItems 个条目。',
        evidence: [for (final s in doc.sections) '${s.title}(${s.items.length})'],
      ),
      EvalDimension(
        key: 'language',
        label: kDimensionLabels['language']!,
        score: languageScore,
        comment: '基于动词强度、弱化词与占位符的启发式判断。',
        evidence: const [],
      ),
      EvalDimension(
        key: 'ats',
        label: kDimensionLabels['ats']!,
        score: atsScore,
        comment: atsKeywords.isEmpty
            ? '无岗位关键词，按标准章节结构评分。'
            : 'ATS 关键词覆盖：${_matchedRatio(atsKeywords, fullText)}%。',
        evidence: [
          if (doc.header.photoPath != null && doc.header.photoPath!.isNotEmpty)
            '含照片（部分 ATS 不友好）',
          '标准章节：${_standardHeadings(doc).join('、')}',
        ],
      ),
      EvalDimension(
        key: 'differentiation',
        label: kDimensionLabels['differentiation']!,
        score: differentiationScore,
        comment: '亮点/标签/独特经历的启发式判断。',
        evidence: [
          if (doc.strengths.isNotEmpty) '含优势清单 ${doc.strengths.length} 条',
          if (hasSummary) '含个人定位',
        ],
      ),
      EvalDimension(
        key: 'density',
        label: kDimensionLabels['density']!,
        score: densityScore,
        comment: '约 $chars 字，目标 ${request.pageLimit > 0 ? '${request.pageLimit} 页' : '不限页数'}。',
        evidence: const [],
      ),
    ];

    final overall = ResumeEvaluation.computeOverall(dimensions);

    final missing = <EvalMissingItem>[];
    final recs = <EvalRecommendation>[];

    void rec(String item, int gain, String effort, String rationale) => recs.add(
          EvalRecommendation(item: item, expectedGain: gain, effort: effort, rationale: rationale),
        );

    if (!hasContact) {
      missing.add(const EvalMissingItem(
        item: '联系方式',
        why: '缺少邮箱/电话等联系信息，招聘方无法联系。',
        suggestion: '在个人资料中补充邮箱、电话、城市与主页。',
        severity: 'high',
      ));
      rec('补充联系方式（邮箱/电话/主页）', 12, 'low', '基础必备项，几乎零成本。');
    }
    if (!hasEdu) {
      missing.add(const EvalMissingItem(
        item: '教育经历',
        why: '教育背景是多数岗位的硬性筛选项。',
        suggestion: '补录学校、专业、学历与时间。',
        severity: 'high',
      ));
      rec('补充教育经历', 18, 'medium', '提升完整度与 ATS 命中。');
    }
    if (!hasExp) {
      missing.add(const EvalMissingItem(
        item: '工作/实习经历',
        why: '经历是简历的核心证据。',
        suggestion: '补录实习/工作，并用 STAR 写出成果。',
        severity: 'high',
      ));
      rec('补充工作/实习经历', 22, 'medium', '对匹配度与可信度提升最大。');
    }
    if (!hasSkills) {
      missing.add(const EvalMissingItem(
        item: '技能清单',
        why: '技能是 ATS 关键词的主要载体。',
        suggestion: '按目标岗位列出硬技能与工具。',
        severity: 'high',
      ));
      rec('补充技能清单并对齐 JD 用词', 16, 'low', '低成本提升关键词覆盖。');
    }
    if (!hasSummary) {
      missing.add(const EvalMissingItem(
        item: '个人简介',
        why: '缺少一句话定位，招聘方难以快速判断匹配。',
        suggestion: '写 2–3 句定位 + 核心优势。',
        severity: 'medium',
      ));
      rec('补写个人简介/headline', 10, 'low', '快速提升开头吸引力。');
    }
    if (impactScore < 50) {
      missing.add(EvalMissingItem(
        item: '量化成果',
        why: '大量条目缺少数字，说服力不足。',
        suggestion: '给关键 bullet 加上规模/比例/金额/周期等数字。',
        severity: impactScore < 25 ? 'high' : 'medium',
      ));
      rec('为关键经历补充量化数字', 18, 'low', 'STAR/XYZ 量化是高分要点。');
    }
    if (targetKeywords.isNotEmpty && matchScore < 55) {
      missing.add(const EvalMissingItem(
        item: '目标岗位关键词',
        why: '简历措辞与目标岗位/企业匹配度偏低。',
        suggestion: '把 JD 中的硬技能与工具名原样写入技能与经历。',
        severity: 'high',
      ));
      rec('对齐目标岗位关键词', 20, 'low', '直接提升匹配度与 ATS。');
    }
    if (atsScore < 60) {
      missing.add(const EvalMissingItem(
        item: 'ATS 友好度',
        why: '章节结构或关键词不利机器筛选。',
        suggestion: '使用标准章节标题，避免照片/多栏/图形。',
        severity: 'medium',
      ));
      rec('优化 ATS 结构（标准章节/单列）', 10, 'low', '降低被过滤风险。');
    }
    final hasLink = doc.header.contacts.any(
          (c) => (c.url ?? '').trim().isNotEmpty || c.value.contains('http'),
        );
    final hasAttachment = doc.sections.any((s) => s.items.any((i) => i.attachments.isNotEmpty));
    if (!hasLink && !hasAttachment) {
      missing.add(const EvalMissingItem(
        item: '作品/链接',
        why: '缺少主页、GitHub 或作品集佐证。',
        suggestion: '补充个人主页/GitHub/作品链接；技术岗尤其重要。',
        severity: 'medium',
      ));
      rec('补充作品集/主页链接', 8, 'low', '增强可信度与差异化。');
    }
    if (request.pageLimit > 0) {
      final target = request.pageLimit * 900.0;
      if (chars > target * 1.2) {
        missing.add(const EvalMissingItem(
          item: '篇幅超限',
          why: '内容超过目标页数，可能被截断或显得冗长。',
          suggestion: '压缩弱相关经历，删去无结果描述。',
          severity: 'medium',
        ));
        rec('精简篇幅至目标页数内', 9, 'low', '提升可读性。');
      } else if (chars < target * 0.5) {
        missing.add(const EvalMissingItem(
          item: '内容偏薄',
          why: '内容量低于目标页数，信息密度不足。',
          suggestion: '补充项目细节与量化成果，或调整页数目标。',
          severity: 'medium',
        ));
        rec('补充项目细节与成果', 12, 'medium', '充实内容与匹配度。');
      }
    }
    if (differentiationScore < 50) {
      missing.add(const EvalMissingItem(
        item: '差异化亮点',
        why: '简历缺少独特优势标签，易与同类候选人同质化。',
        suggestion: '提炼 2–3 条独家优势或高含金量成果。',
        severity: 'medium',
      ));
      rec('提炼差异化亮点清单', 10, 'medium', '提升区分度。');
    }
    if (languageScore < 60) {
      missing.add(const EvalMissingItem(
        item: '专业表达',
        why: '存在弱化动词或占位文本，降低专业感。',
        suggestion: '用强动词开头，清除「待补充/TODO」等占位符。',
        severity: 'low',
      ));
      rec('润色动词与清除占位文本', 8, 'low', '低成本提升专业度。');
    }

    if (recs.isEmpty) {
      rec('保持与目标岗位对齐，持续加入新成果', 5, 'low', '整体已较完善，边际收益有限。');
    }

    final ranked = _rankByMarginalBenefit(recs);

    return ResumeEvaluation(
      overall: overall,
      dimensions: dimensions,
      missing: missing,
      recommendations: ranked,
      targetRole: request.targetRole.trim().isEmpty ? null : request.targetRole.trim(),
      targetCompany: request.targetCompany.trim().isEmpty ? null : request.targetCompany.trim(),
      summary: _summaryText(overall, missing, dimensions),
      aiAssisted: false,
      model: null,
      generatedAt: now ?? DateTime.now(),
    );
  }

  // --- AI 评估 ---

  /// 调用 LLM 评估；解析失败返回 [Err]，由调用方回退启发式。
  Future<Result<ResumeEvaluation>> evaluateWithAi({
    required ResumeDocument doc,
    required ExportRequest request,
    required String baseUrl,
    required String apiKey,
    required String model,
  }) async {
    final payload = <String, dynamic>{
      'export_request': request.toJson(),
      'resume': doc.toJson(),
    };
    final user = StringBuffer()
      ..writeln('【待处理数据开始】')
      ..writeln(jsonEncode(payload))
      ..writeln('【待处理数据结束】')
      ..writeln('请仅输出评估 JSON（dimensions/missing/recommendations/overall/summary）。');

    final res = await llm.chatCompletion(
      baseUrl: baseUrl,
      apiKey: apiKey,
      model: model,
      jsonMode: true,
      messages: [
        LlmMessage.text('system', evalSystemPrompt),
        LlmMessage.text('user', user.toString()),
      ],
    );
    if (res.isErr) return Err(res.errorMessage!);

    try {
      final decoded = jsonDecode(extractJsonBlock(res.valueOrNull ?? ''));
      if (decoded is! Map) return const Err('模型未返回合法评估 JSON。');
      var map = decoded.cast<String, dynamic>();
      final inner = map['evaluation'] ?? map['result'];
      if (inner is Map) map = inner.cast<String, dynamic>();
      final eval = ResumeEvaluation.fromJson(map);
      if (eval.dimensions.isEmpty) {
        return const Err('模型评估缺少 dimensions 字段。');
      }
      final overall =
          eval.overall > 0 ? eval.overall : ResumeEvaluation.computeOverall(eval.dimensions);
      return Ok(eval.copyWith(
        overall: overall,
        targetRole: request.targetRole.trim().isEmpty ? eval.targetRole : request.targetRole.trim(),
        targetCompany:
            request.targetCompany.trim().isEmpty ? eval.targetCompany : request.targetCompany.trim(),
        aiAssisted: true,
        model: model,
        generatedAt: DateTime.now(),
      ));
    } catch (e) {
      return Err('解析模型评估失败：$e', e);
    }
  }

  // --- 评分辅助 ---

  int _matchScore(ResumeDocument doc, Set<String> keywords, List<String> itemTexts) {
    if (keywords.isEmpty) return 60;
    final hay = itemTexts.join(' ').toLowerCase();
    var score = (_matchedRatio(keywords, hay) * 100).round();
    final role = (doc.meta['target_role'] ?? '').toString().toLowerCase();
    if (role.trim().isNotEmpty && hay.contains(role.trim())) score = math.min(100, score + 15);
    return score.clamp(0, 100);
  }

  int _impactScore(List<String> bullets, ResumeDocument doc, List<String> itemTexts) {
    final pool = bullets.isNotEmpty
        ? bullets
        : [
            for (final s in doc.sections)
              for (final i in s.items)
                if ((i.description ?? '').trim().isNotEmpty) i.description!,
          ];
    if (pool.isEmpty) {
      final hay = itemTexts.join(' ');
      return _quantPattern.hasMatch(hay) ? 40 : 10;
    }
    final quantified = pool.where(_quantPattern.hasMatch).length;
    return (quantified / pool.length * 100).round().clamp(0, 100);
  }

  int _structureScore(ResumeDocument doc, int totalItems, bool hasSummary) {
    final nonEmpty = doc.sections.where((s) => s.items.isNotEmpty).toList();
    if (nonEmpty.isEmpty) return 0;
    var score = 50;
    if (doc.sections.length >= 3) score += 15;
    if (nonEmpty.length >= 2) score += 10;
    if (hasSummary) score += 10;
    if (doc.strengths.isNotEmpty) score += 10;
    if (nonEmpty.length > 1 && totalItems > 0) {
      final maxItems = nonEmpty.map((s) => s.items.length).reduce(math.max);
      if (maxItems / totalItems > 0.7) score -= 12;
    }
    return score.clamp(0, 100);
  }

  int _languageScore(
    List<String> bullets,
    List<String> itemTexts,
    bool hasSummary,
    String? summary,
  ) {
    final text = [...bullets, ...itemTexts, summary ?? ''].join(' ').toLowerCase();
    final strong = _strongVerbs.where(text.contains).length;
    final weak = _weakPhrases.where(text.contains).length;
    var score = 75;
    score += math.min(15, strong * 3);
    score -= math.min(20, weak * 2);
    if (_placeholderPattern.hasMatch(text)) score -= 30;
    if (bullets.isNotEmpty) {
      final avg = bullets.map((b) => b.runes.length).reduce((a, b) => a + b) / bullets.length;
      if (avg >= 15 && avg <= 100) {
        score += 10;
      } else if (avg > 150) {
        score -= 10;
      }
    }
    if (hasSummary) score += 5;
    return score.clamp(0, 100);
  }

  int _atsScore(ResumeDocument doc, Set<String> keywords) {
    final standard = _standardHeadings(doc).isNotEmpty;
    final hay = _docText(doc).toLowerCase();
    int score;
    if (keywords.isEmpty) {
      score = standard ? 80 : 55;
    } else {
      score = (45 + _matchedRatio(keywords, hay) * 45).round();
      if (standard) score = math.min(100, score + 10);
    }
    if (doc.header.photoPath != null && doc.header.photoPath!.trim().isNotEmpty) {
      score -= 15;
    }
    return score.clamp(0, 100);
  }

  int _differentiationScore(ResumeDocument doc) {
    var score = 40;
    if (doc.strengths.isNotEmpty) score += 20;
    if ((doc.summary ?? '').trim().isNotEmpty) score += 15;
    final hasSpecial = doc.sections.any((s) => _specialSections.any(
          (n) => '${s.key} ${s.title}'.toLowerCase().contains(n),
        ));
    if (hasSpecial) score += 10;
    final tags = <String>{for (final s in doc.sections) for (final i in s.items) ...i.tags};
    if (tags.length >= 5) score += 10;
    final hasLink = doc.header.contacts.any((c) => (c.url ?? '').trim().isNotEmpty);
    if (hasLink) score += 5;
    return score.clamp(0, 100);
  }

  int _densityScore(int chars, int pageLimit) {
    if (chars == 0) return 0;
    final target = pageLimit > 0 ? pageLimit * 900.0 : 1600.0;
    final ratio = chars / target;
    double score;
    if (ratio < 0.6) {
      score = 90 * (ratio / 0.6);
    } else if (ratio <= 1.15) {
      score = 100;
    } else {
      score = 100 - (ratio - 1.15) * 80;
    }
    return score.round().clamp(0, 100);
  }

  List<EvalRecommendation> _rankByMarginalBenefit(List<EvalRecommendation> recs) {
    double factor(String effort) => switch (effort) {
          'low' => 1.0,
          'high' => 0.35,
          _ => 0.6,
        };
    final sorted = [...recs]
      ..sort((a, b) {
        final va = a.expectedGain * factor(a.effort);
        final vb = b.expectedGain * factor(b.effort);
        return vb.compareTo(va);
      });
    return [
      for (var i = 0; i < sorted.length; i++)
        EvalRecommendation(
          item: sorted[i].item,
          expectedGain: sorted[i].expectedGain,
          effort: sorted[i].effort,
          priority: i + 1,
          rationale: sorted[i].rationale,
        ),
    ];
  }

  String _summaryText(int overall, List<EvalMissingItem> missing, List<EvalDimension> dims) {
    final weakest = [...dims]..sort((a, b) => a.score.compareTo(b.score));
    final tail = weakest.isEmpty ? '' : '；当前最弱维度为「${weakest.first.label}」。';
    if (missing.isEmpty) {
      return '综合评分 $overall/100，整体较完善$tail';
    }
    return '综合评分 $overall/100，共发现 ${missing.length} 项可改进点$tail';
  }

  List<String> _evidenceKeywords(ResumeDocument doc, Set<String> keywords, List<String> itemTexts) {
    final hay = itemTexts.join(' ').toLowerCase();
    return keywords.where((k) => hay.contains(k)).take(8).toList();
  }

  List<String> _evidenceQuant(List<String> bullets) =>
      bullets.where(_quantPattern.hasMatch).take(6).toList();

  double _matchedRatio(Set<String> keywords, String hay) {
    if (keywords.isEmpty) return 0;
    final lower = hay.toLowerCase();
    final matched = keywords.where(lower.contains).length;
    return matched / keywords.length;
  }

  List<String> _standardHeadings(ResumeDocument doc) {
    final out = <String>[];
    for (final s in doc.sections) {
      final h = '${s.key} ${s.title}'.toLowerCase();
      for (final n in _standardSectionNeedles) {
        if (h.contains(n) && !out.contains(s.title)) out.add(s.title);
      }
    }
    return out;
  }

  bool _hasSection(ResumeDocument doc, List<String> needles) {
    for (final s in doc.sections) {
      if (s.items.isEmpty) continue;
      final h = '${s.key} ${s.title}'.toLowerCase();
      if (needles.any(h.contains)) return true;
    }
    return false;
  }

  List<String> _allBullets(ResumeDocument doc) => [
        for (final s in doc.sections)
          for (final i in s.items) ...i.bullets.where((b) => b.trim().isNotEmpty),
      ];

  List<String> _itemTexts(ResumeDocument doc) => [
        doc.header.name,
        doc.header.headline ?? '',
        doc.summary ?? '',
        ...doc.strengths,
        for (final s in doc.sections) s.title,
        for (final s in doc.sections)
          for (final i in s.items) ...[
            i.title,
            i.subtitle ?? '',
            i.description ?? '',
            ...i.tags,
            ...i.bullets,
          ],
      ].where((e) => e.trim().isNotEmpty).toList();

  String _docText(ResumeDocument doc) {
    final b = StringBuffer()
      ..writeln(doc.header.name)
      ..writeln(doc.header.englishName ?? '')
      ..writeln(doc.header.headline ?? '')
      ..writeln(doc.summary ?? '')
      ..writeln(doc.strengths.join(' '));
    for (final c in doc.header.contacts) {
      b.writeln('${c.label} ${c.value} ${c.url ?? ''}');
    }
    for (final s in doc.sections) {
      b.writeln('${s.key} ${s.title}');
      for (final i in s.items) {
        b.writeln(i.title);
        b.writeln(i.subtitle ?? '');
        b.writeln(i.meta ?? '');
        b.writeln(i.description ?? '');
        b.writeln(i.bullets.join(' '));
        b.writeln(i.tags.join(' '));
        for (final v in i.fields.values) {
          b.writeln('$v');
        }
      }
    }
    return b.toString();
  }

  Set<String> _keywordsFrom(Iterable<String> sources) {
    final out = <String>{};
    for (final raw in sources) {
      for (final part in raw.split(_separator)) {
        final w = part.trim().toLowerCase();
        if (w.isEmpty) continue;
        if (_cjk.hasMatch(w)) {
          if (w.runes.length >= 2) out.add(w);
          if (w.runes.length >= 3) {
            final runes = w.runes.toList();
            for (var i = 0; i + 2 <= runes.length; i++) {
              out.add(String.fromCharCodes(runes.sublist(i, i + 2)));
            }
          }
        } else if (w.length >= 2) {
          out.add(w);
        }
      }
    }
    return out;
  }

  int _charCount(String s) => s.replaceAll(_whitespace, '').runes.length;
}

// --- 常量与正则 ---

final RegExp _separator = RegExp(r'[\s,，、;；/|\\()\[\]{}<>:：·•\-—_]+');
final RegExp _whitespace = RegExp(r'\s+');
final RegExp _cjk = RegExp(r'[\u4e00-\u9fff]');

/// 量化特征：数字 + 单位/百分比/倍数，或「从 X 到 Y」。
final RegExp _quantPattern = RegExp(
  r'(\d[\d,\.]*\s*(%|％|倍|万|亿|元|¥|\$|人|天|周|月|年|次|个|分|名|篇|项|条|台|套|TB|GB|MB|KB|ms|QPS|qps|req|rps|x|w|W|k|K))'
  r'|(\d[\d,\.]*\s*(增长|提升|降低|下降|优化|节省|翻))'
  r'|(从\s*\d+\s*到\s*\d+)',
);

final RegExp _placeholderPattern =
    RegExp(r'(待补充|待完善|待填写|todo|xxx|？？？|###)', caseSensitive: false);

const List<String> _strongVerbs = [
  '主导', '设计', '开发', '搭建', '优化', '推动', '落地', '实现',
  '重构', '交付', '构建', '引入', '解决', '提升', '降低', '增长',
];

const List<String> _weakPhrases = ['负责', '参与', '协助', '帮助', '做了', '进行了'];

const List<String> _standardSectionNeedles = [
  'contact', '联系', 'summary', '简介', 'skill', '技能',
  'experience', '经历', 'education', '教育', 'project', '项目',
];

const List<String> _specialSections = [
  'project', '项目', 'research', '科研', 'award', '奖', 'publication', '论文',
];
