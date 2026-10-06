/// 定向简历「一体两面」评估服务。
///
/// - [evaluateHeuristic]：纯本地、确定性、离线可用的启发式评估，同时产出
///   **岗位适配诊断（fit）** 与 **客观质量评分（objective）**。
/// - [evaluateWithAi]：调用 LLM 评估；模型输出按**不可信数据**解析，
///   解析失败返回 [Err]，调用方回退启发式结果。
library;

import 'dart:convert';
import 'dart:math' as math;

import '../../core/result.dart';
import '../../data/models/export_request.dart';
import '../../data/models/resume_doc.dart';
import '../../data/models/resume_eval.dart';
import '../../data/role_profiles.dart';
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
    final hay = fullText.toLowerCase();

    final hasEdu = _hasSection(doc, const ['education', '教育', '学历', '学校', 'academic']);
    final hasExp = _hasSection(doc, const ['experience', '工作', '实习', '经历', 'employment']);
    final hasSkills = _hasSection(doc, const ['skill', '技能', '能力', '专长', '技术栈']);
    final hasContact = doc.header.contacts.isNotEmpty;
    final hasSummary = (doc.summary ?? '').trim().isNotEmpty;
    final totalItems = doc.sections.fold<int>(0, (a, s) => a + s.items.length);
    final hasLink = doc.header.contacts.any(
      (c) => (c.url ?? '').trim().isNotEmpty || c.value.contains('http'),
    );

    final atsKeywords = _keywordsFrom([
      request.targetRole,
      request.targetCompany,
      request.industry,
      request.emphasis,
      ...request.mustInclude,
    ]);

    // --- 客观质量评分（objective，去掉 match） ---

    var hits = 0;
    if (hasContact) hits++;
    if (hasEdu) hits++;
    if (hasExp) hits++;
    if (hasSkills) hits++;
    var completenessScore = (hits / 4 * 100).round();
    if (hasSummary) completenessScore = math.min(100, completenessScore + 8);
    if (totalItems == 0) completenessScore = math.min(completenessScore, 20);

    final impactScore = _impactScore(bullets, doc, itemTexts);
    final structureScore = _structureScore(doc, totalItems, hasSummary);
    final languageScore = _languageScore(bullets, itemTexts, hasSummary, doc.summary);
    final atsScore = _atsScore(doc, atsKeywords);
    final differentiationScore = _differentiationScore(doc);
    final densityScore = _densityScore(chars, request.pageLimit);

    final dimensions = <EvalDimension>[
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
      ),
      EvalDimension(
        key: 'ats',
        label: kDimensionLabels['ats']!,
        score: atsScore,
        comment: atsKeywords.isEmpty
            ? '无岗位关键词，按标准章节结构评分。'
            : 'ATS 关键词覆盖：${(_matchedRatio(atsKeywords, hay) * 100).round()}%。',
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
        comment:
            '约 $chars 字，目标 ${request.pageLimit > 0 ? '${request.pageLimit} 页' : '不限页数'}。',
      ),
    ];

    final overall = ObjectiveScore.computeOverall(dimensions);
    final sortedDims = [...dimensions]..sort((a, b) => b.score.compareTo(a.score));
    final strengths = [
      for (final d in sortedDims)
        if (d.score >= 80) d.label,
    ];
    final weaknesses = [
      for (final d in sortedDims.reversed)
        if (d.score < 60) d.label,
    ];
    if (strengths.isEmpty && sortedDims.isNotEmpty) strengths.add(sortedDims.first.label);
    if (weaknesses.isEmpty && sortedDims.isNotEmpty) weaknesses.add(sortedDims.last.label);
    final objective = ObjectiveScore(
      overall: overall,
      dimensions: dimensions,
      strengths: strengths,
      weaknesses: weaknesses,
      summary: _objectiveSummary(overall, sortedDims),
    );

    // --- 岗位适配诊断（fit） ---

    final fit = _buildFit(
      request: request,
      hay: hay,
      hasLink: hasLink,
      hasExp: hasExp,
      impactScore: impactScore,
    );

    return ResumeEvaluation(
      fit: fit,
      objective: objective,
      targetRole: request.targetRole.trim().isEmpty ? null : request.targetRole.trim(),
      targetCompany:
          request.targetCompany.trim().isEmpty ? null : request.targetCompany.trim(),
      aiAssisted: false,
      model: null,
      generatedAt: now ?? DateTime.now(),
    );
  }

  FitAnalysis _buildFit({
    required ExportRequest request,
    required String hay,
    required bool hasLink,
    required bool hasExp,
    required int impactScore,
  }) {
    final roleText = request.targetRole.trim();
    final profile = RoleProfiles.match(roleText);
    if (profile == null) {
      return _genericFit(
        roleText: roleText,
        hay: hay,
        hasLink: hasLink,
        impactScore: impactScore,
      );
    }

    final hardReqs = <HardRequirement>[];
    final missing = <FitMissingItem>[];
    final certStatus = <String, String>{};

    var certHave = 0;
    for (final c in profile.requiredCerts) {
      String? hit;
      for (final t in _certTerms(c.name)) {
        if (_mentions(hay, t)) {
          hit = t;
          break;
        }
      }
      final status = hit != null ? 'have' : 'missing';
      certStatus[c.name] = status;
      if (status == 'have') certHave++;
      hardReqs.add(HardRequirement(
        name: c.name,
        status: status,
        importance: c.mandatory ? 'required' : 'preferred',
        evidence: hit == null ? '' : '简历中出现「$hit」',
        note: hit != null
            ? '已满足。'
            : (c.mandatory ? '硬性门槛，缺失将大概率被直接筛掉。' : '加分项，缺失降低竞争力但不阻断投递。'),
      ));
      if (status == 'missing') {
        missing.add(FitMissingItem(
          item: c.name,
          category: 'cert',
          importance: c.mandatory ? 'required' : 'preferred',
          why: c.mandatory ? '多数岗位的硬性准入条件。' : '常用加分项，可提升竞争力。',
          suggestion: '尽快报名获取「${c.name}」。',
        ));
      }
    }

    final missingSkills = profile.coreSkills.where((s) => !_mentions(hay, s)).toList();
    final skillRatio = profile.coreSkills.isEmpty
        ? 1.0
        : (profile.coreSkills.length - missingSkills.length) / profile.coreSkills.length;
    for (final s in missingSkills) {
      missing.add(FitMissingItem(
        item: s,
        category: 'skill',
        importance: 'required',
        why: '目标岗位核心技能，简历未体现。',
        suggestion: '通过学习/项目补上「$s」，并在技能与经历中量化落地。',
      ));
    }

    final missingExps =
        profile.typicalExperiences.where((e) => !_mentions(hay, e)).toList();
    final expRatio = profile.typicalExperiences.isEmpty
        ? 1.0
        : (profile.typicalExperiences.length - missingExps.length) /
            profile.typicalExperiences.length;
    for (final e in missingExps) {
      missing.add(FitMissingItem(
        item: e,
        category: 'experience',
        importance: 'required',
        why: '该岗位看重的典型经历，简历缺少同类证据。',
        suggestion: '争取/补充「$e」，并用 STAR 写出量化成果。',
      ));
    }

    final certRatio = profile.requiredCerts.isEmpty
        ? null
        : certHave / profile.requiredCerts.length;

    double score;
    if (certRatio == null) {
      score = skillRatio * 0.6 + expRatio * 0.4;
    } else {
      score = certRatio * 0.4 + skillRatio * 0.35 + expRatio * 0.25;
    }
    var fitScore = (score * 100).round().clamp(0, 100);
    final hasMandatoryMissing = profile.requiredCerts
        .any((c) => c.mandatory && certStatus[c.name] == 'missing');
    if (hasMandatoryMissing) fitScore = math.min(fitScore, 60);

    // 行动清单：过滤已满足项，按「预估提升 × 投入权重」排序赋 priority。
    final recs = <FitAction>[];
    for (final a in profile.actions) {
      if (_actionSatisfied(a, certStatus)) continue;
      var gain = a.expectedGain;
      final actionLower = a.action.toLowerCase();
      for (final c in profile.requiredCerts) {
        if (c.mandatory &&
            certStatus[c.name] == 'missing' &&
            _certTerms(c.name).any((t) => _mentions(actionLower, t))) {
          gain += 8;
        }
      }
      recs.add(FitAction(
        action: a.action,
        category: a.category,
        expectedGain: gain.clamp(0, 100),
        effort: a.effort,
        timeEstimate: a.timeEstimate,
        priority: 0,
        rationale: a.rationale,
        resources: a.resources,
      ));
    }
    if (recs.isEmpty) {
      recs.add(FitAction(
        action: '保持与目标岗位对齐，持续积累新成果',
        category: 'other',
        expectedGain: 5,
        effort: 'low',
        timeEstimate: '长期',
        rationale: '当前画像要点已基本满足，边际收益有限。',
      ));
    }

    final summary = '目标岗位「${profile.name}」：硬性证书命中 $certHave/'
        '${profile.requiredCerts.length}，核心技能覆盖 ${(skillRatio * 100).round()}%，'
        '典型经历覆盖 ${(expRatio * 100).round()}%，共 ${missing.length} 项待补齐。';

    return FitAnalysis(
      fitScore: fitScore,
      hardRequirements: hardReqs,
      missing: missing,
      recommendations: rankByMarginalBenefit(recs),
      summary: summary,
      roleProfileId: profile.id,
      roleName: profile.name,
    );
  }

  FitAnalysis _genericFit({
    required String roleText,
    required String hay,
    required bool hasLink,
    required int impactScore,
  }) {
    final missing = <FitMissingItem>[];
    final recs = <FitAction>[];
    var fitScore = 0;
    String summary;

    if (roleText.isEmpty) {
      summary = '未填写目标岗位，无法进行针对性适配诊断；建议在问卷中补充目标岗位。';
    } else {
      final kws = _keywordsFrom([roleText]);
      final ratio = _matchedRatio(kws, hay);
      fitScore = (30 + ratio * 50).round().clamp(0, 100);
      summary = '未识别到内置画像，按目标关键词「$roleText」覆盖率 '
          '${(ratio * 100).round()}% 估算适配度。';
      if (ratio < 0.6) {
        missing.add(const FitMissingItem(
          item: '目标岗位关键词',
          category: 'skill',
          importance: 'required',
          why: '简历措辞与目标岗位匹配不足，ATS/HR 难以判断相关性。',
          suggestion: '把 JD 中的硬技能与工具名原样写入技能与经历。',
        ));
      }
    }

    if (impactScore < 50) {
      missing.add(const FitMissingItem(
        item: '量化成果',
        category: 'other',
        importance: 'required',
        why: '关键经历缺少数字，说服力不足。',
        suggestion: '用规模/比例/金额/周期量化关键经历。',
      ));
    }
    if (!hasLink) {
      missing.add(const FitMissingItem(
        item: '作品/主页链接',
        category: 'portfolio',
        importance: 'preferred',
        why: '缺少可验证的佐证材料。',
        suggestion: '补充 GitHub / 作品集 / 个人主页。',
      ));
    }

    void add(String action, String category, int gain, String effort, String time,
        String rationale, [List<String> resources = const []]) {
      recs.add(FitAction(
        action: action,
        category: category,
        expectedGain: gain,
        effort: effort,
        timeEstimate: time,
        priority: 0,
        rationale: rationale,
        resources: resources,
      ));
    }

    add('为关键经历补充量化数字', 'other', 18, 'low', '1 天',
        'STAR/XYZ 量化是提升可信度与评分的最低成本手段。');
    add('补充与目标岗位相关的实习/项目', 'experience', 22, 'medium', '1–3 个月',
        '相关经历是匹配度最强的证据，直接提升录取概率。');
    add('补充证书/资质或作品集', 'cert', 15, 'low', '1–2 周',
        '证书与作品集可快速补强硬性条件与差异化。');
    if (roleText.isNotEmpty) {
      add('对齐目标岗位关键词', 'skill', 20, 'low', '1 天',
          '将 JD 术语原样写入简历，提升 ATS 与 HR 相关性判断。');
    }

    return FitAnalysis(
      fitScore: fitScore,
      missing: missing,
      recommendations: rankByMarginalBenefit(recs),
      summary: summary,
    );
  }

  /// 已满足判定：若某必需证书已具备且该行动明显指向它，则视为已完成。
  bool _actionSatisfied(RoleAction a, Map<String, String> certStatus) {
    final al = a.action.toLowerCase();
    for (final e in certStatus.entries) {
      if (e.value == 'have' && _certTerms(e.key).any((t) => _mentions(al, t))) {
        return true;
      }
    }
    return false;
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
      ..writeln('请仅输出评估 JSON（fit 与 objective 两段）。');

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
      var eval = ResumeEvaluation.fromJson(map);
      if (eval.objective.dimensions.isEmpty && eval.fit.recommendations.isEmpty) {
        return const Err('模型评估缺少 objective.dimensions / fit 字段。');
      }
      final overall = eval.objective.overall > 0
          ? eval.objective.overall
          : ObjectiveScore.computeOverall(eval.objective.dimensions);
      eval = eval.copyWith(
        objective: eval.objective.copyWith(overall: overall),
        targetRole: request.targetRole.trim().isEmpty
            ? eval.targetRole
            : request.targetRole.trim(),
        targetCompany: request.targetCompany.trim().isEmpty
            ? eval.targetCompany
            : request.targetCompany.trim(),
        aiAssisted: true,
        model: model,
        generatedAt: DateTime.now(),
      );
      return Ok(eval);
    } catch (e) {
      return Err('解析模型评估失败：$e', e);
    }
  }

  /// 按「预估提升 × 投入权重」降序赋 priority（=边际效益排序）。
  static List<FitAction> rankByMarginalBenefit(List<FitAction> recs) {
    double factor(String effort) => switch (effort) {
          'low' => 1.0,
          'high' => 0.35,
          _ => 0.6,
        };
    final indexed = [for (var i = 0; i < recs.length; i++) (i, recs[i])];
    indexed.sort((a, b) {
      final va = a.$2.expectedGain * factor(a.$2.effort);
      final vb = b.$2.expectedGain * factor(b.$2.effort);
      final c = vb.compareTo(va);
      return c != 0 ? c : a.$1.compareTo(b.$1);
    });
    return [
      for (var i = 0; i < indexed.length; i++)
        FitAction(
          action: indexed[i].$2.action,
          category: indexed[i].$2.category,
          expectedGain: indexed[i].$2.expectedGain,
          effort: indexed[i].$2.effort,
          timeEstimate: indexed[i].$2.timeEstimate,
          priority: i + 1,
          rationale: indexed[i].$2.rationale,
          resources: indexed[i].$2.resources,
          done: indexed[i].$2.done,
        ),
    ];
  }

  // --- 评分辅助 ---

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

  String _objectiveSummary(int overall, List<EvalDimension> sortedDims) {
    final tail = sortedDims.isEmpty ? '' : '；当前最弱维度为「${sortedDims.last.label}」。';
    return '客观质量评分 $overall/100$tail';
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

// --- 岗位匹配辅助 ---

/// 证书名 -> 可命中词（去掉「证/证书」后缀、拆分斜杠、提取等级前缀）。
Set<String> _certTerms(String name) {
  final out = <String>{};
  final cleaned = name.replaceAll(RegExp(r'[（(].*?[）)]'), '');
  for (final part in cleaned.split(RegExp(r'[/、,，]'))) {
    var p = part.trim();
    if (p.isEmpty) continue;
    out.add(p);
    if (p.endsWith('证书') && p.length > 2) {
      p = p.substring(0, p.length - 2);
    } else if (p.endsWith('证') && p.length > 1) {
      p = p.substring(0, p.length - 1);
    }
    out.add(p);
    if (p.contains('资格证')) out.add(p.replaceAll('资格证', '资格'));
    if (p.contains('等级证')) out.add(p.replaceAll('等级证', ''));
    if (p.contains('等级')) {
      final idx = p.indexOf('等级');
      if (idx >= 2) out.add(p.substring(0, idx));
    }
    if (p.contains('合格证')) {
      final idx = p.indexOf('合格证');
      if (idx >= 2) out.add(p.substring(0, idx));
    }
  }
  out.removeWhere((e) => e.trim().length < 2);
  return out;
}

/// 在已小写的全文里判断某个（可能含 /、括号的）词是否出现（任一子词命中即算）。
bool _mentions(String hayLower, String term) {
  final t = term.toLowerCase().trim();
  if (t.isEmpty) return false;
  for (final rawPart in t.split(RegExp(r'[/、,，()（）]'))) {
    final p = rawPart.trim();
    if (p.length < 2) continue;
    if (hayLower.contains(p)) return true;
  }
  return false;
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
