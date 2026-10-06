/// 简历模板注册表：集中定义版式风格、配色、适用岗位与 Typst 支持情况。
///
/// 供导出问卷（选择/推荐）、渲染器（按 layout 出不同版式）与 UI 共用。
library;

import '../../data/models/resume_doc.dart';

/// 单套简历模板。
class ResumeTemplate {
  /// 稳定标识（写入 IR/元数据，勿随意改动）。
  final String id;

  /// 展示名。
  final String name;

  /// 一句话说明（UI 展示）。
  final String description;

  /// 风格/受众标签，如 ['单列','ATS','大厂','外企']。
  final List<String> tags;

  /// 适配岗位/场景，如 ['软件','产品','金融']。
  final List<String> bestFor;

  /// 版式：single | two-column | academic | creative | compact | elegant | mono。
  final String layout;

  /// 强调色 0xAARRGGBB。
  final int accentArgb;

  /// 是否有 Typst 模板实现（桌面精品 PDF）。
  final bool typst;

  const ResumeTemplate({
    required this.id,
    required this.name,
    required this.description,
    this.tags = const [],
    this.bestFor = const [],
    required this.layout,
    required this.accentArgb,
    this.typst = true,
  });
}

/// 模板集合：内置 10 套常见岗位风格。
class ResumeTemplates {
  const ResumeTemplates._();

  /// 默认模板：通用单列 ATS。
  static const String defaultId = 'ats-classic';

  static const List<ResumeTemplate> _all = [
    ResumeTemplate(
      id: 'ats-classic',
      name: 'ATS 经典单列',
      description: '朴素单列、标准标题，机器解析友好，最稳妥的通用选择。',
      tags: ['单列', 'ATS', '大厂', '外企', '通用'],
      bestFor: ['软件', '产品', '运营', '外企', '大厂', '校招'],
      layout: 'single',
      accentArgb: 0xFF2E5C8A,
    ),
    ResumeTemplate(
      id: 'modern-two-col',
      name: '现代双栏',
      description: '左侧主经历、右侧技能/证书侧栏，信息密度高，适合互联网技术岗。',
      tags: ['双栏', '现代', '互联网', '技术'],
      bestFor: ['互联网', '技术', '前端', '全栈', '产品', '研发'],
      layout: 'two-column',
      accentArgb: 0xFF2563EB,
    ),
    ResumeTemplate(
      id: 'academic-cv',
      name: '学术 CV',
      description: '居中标题、论文/科研前置，不限页数，适合科研、读研与教职。',
      tags: ['学术', '科研', 'CV', '长简历'],
      bestFor: ['科研', '读研', '教职', '博士', '研究', '学术'],
      layout: 'academic',
      accentArgb: 0xFF374151,
    ),
    ResumeTemplate(
      id: 'fresh-graduate',
      name: '应届生一页',
      description: '教育背景与项目经历前置、紧凑一页，突出可塑性。',
      tags: ['应届', '一页', '教育优先', '项目优先'],
      bestFor: ['应届', '校招', '实习', '毕业生', 'graduate'],
      layout: 'compact',
      accentArgb: 0xFF0EA5E9,
    ),
    ResumeTemplate(
      id: 'teacher',
      name: '教师版',
      description: '教育背景与资格证书优先，突出版书/教研/获奖经历。',
      tags: ['教育', '证书优先', '稳定'],
      bestFor: ['教师', '教育', '教研', '培训', '校长'],
      layout: 'compact',
      accentArgb: 0xFF16A34A,
    ),
    ResumeTemplate(
      id: 'creative',
      name: '创意设计',
      description: '彩色标题块与分栏，含作品集/标签区，适合设计创意岗位。',
      tags: ['创意', '设计', '作品集', '彩色'],
      bestFor: ['设计', '视觉', 'UI', 'UX', '广告', '创意'],
      layout: 'creative',
      accentArgb: 0xFFDB2777,
    ),
    ResumeTemplate(
      id: 'business',
      name: '商务简约',
      description: '克制配色、经历优先，专业稳健，适合金融/咨询/法务。',
      tags: ['商务', '简约', '专业', '外企'],
      bestFor: ['金融', '咨询', '银行', '会计', '法务', '商务'],
      layout: 'elegant',
      accentArgb: 0xFF1F2937,
    ),
    ResumeTemplate(
      id: 'tech-compact',
      name: '技术紧凑',
      description: '技能矩阵前置、字号紧凑，突出技术栈与量化成果。',
      tags: ['技术', '紧凑', '技能矩阵', '算法'],
      bestFor: ['算法', '后端', '数据', '大数据', 'AI', '机器学习', '工程'],
      layout: 'compact',
      accentArgb: 0xFF0891B2,
    ),
    ResumeTemplate(
      id: 'elegant-serif',
      name: '优雅衬线',
      description: '居中衬线标题、留白充分，气质文雅，适合综合管理岗。',
      tags: ['优雅', '衬线', '居中', '留白'],
      bestFor: ['管理', '市场', '公关', '文案', '编审'],
      layout: 'elegant',
      accentArgb: 0xFF6B7280,
    ),
    ResumeTemplate(
      id: 'minimal-mono',
      name: '极简单色',
      description: '黑白极简、无装饰线，信息纯净，适合保守行业与打印。',
      tags: ['极简', '单色', '黑白', '打印友好'],
      bestFor: ['通用', '国企', '事业单位', '研究'],
      layout: 'mono',
      accentArgb: 0xFF111111,
    ),
  ];

  /// 全部模板（只读）。
  static List<ResumeTemplate> get all => List.unmodifiable(_all);

  /// 按 id 取模板；未知/空返回默认模板。
  static ResumeTemplate byId(String? id) {
    final key = (id ?? '').trim();
    if (key.isEmpty) return _byIdMap[defaultId]!;
    return _byIdMap[key] ?? _byIdMap[defaultId]!;
  }

  /// 按岗位关键词推荐：命中越多排越前；无命中按内置顺序返回全部。
  static List<ResumeTemplate> recommendFor(List<String> roleKeywords) {
    final keywords = roleKeywords
        .map((e) => e.trim().toLowerCase())
        .where((e) => e.isNotEmpty)
        .toList();
    if (keywords.isEmpty) return all;

    final scores = <String, int>{for (final t in _all) t.id: 0};
    for (final kw in keywords) {
      for (final id in _synonymHits(kw)) {
        scores[id] = (scores[id] ?? 0) + 3;
      }
      for (final t in _all) {
        final hay = '${t.id} ${t.name} ${t.description} '
                '${t.tags.join(' ')} ${t.bestFor.join(' ')}'
            .toLowerCase();
        if (hay.contains(kw)) scores[t.id] = (scores[t.id] ?? 0) + 2;
      }
    }
    final ranked = [..._all];
    // 稳定排序：分数降序，同分保持内置顺序。
    ranked.sort((a, b) {
      final d = (scores[b.id] ?? 0).compareTo(scores[a.id] ?? 0);
      if (d != 0) return d;
      return _all.indexOf(a).compareTo(_all.indexOf(b));
    });
    return ranked;
  }

  /// 岗位关键词 → 模板 id 的同义词映射。
  static List<String> _synonymHits(String kw) {
    bool hit(List<String> words) => words.any((w) => kw.contains(w));
    final out = <String>[];
    if (hit(['教师', '老师', '教研', '培训', '校长', '教学'])) {
      out.add('teacher');
    }
    if (hit(['科研', '研究', '学术', '读研', '教职', '博士', 'phd', 'paper', '论文'])) {
      out.add('academic-cv');
    }
    if (hit(['算法', '后端', '服务端', '大数据', '数据', 'ai', '人工智能', '机器学习', '工程'])) {
      out.add('tech-compact');
    }
    if (hit(['设计', '视觉', '创意', 'ui', 'ux', '作品集', '广告'])) {
      out.add('creative');
    }
    if (hit(['产品', '运营', '互联网', '前端', '全栈', '研发', '技术'])) {
      out.add('modern-two-col');
    }
    if (hit(['金融', '咨询', '银行', '会计', '审计', '法务', '商务', '律师'])) {
      out.add('business');
    }
    if (hit(['应届', '校招', '实习', '毕业生', 'graduate'])) {
      out.add('fresh-graduate');
    }
    if (hit(['外企', '大厂', 'ats', '简历筛选', '国企'])) {
      out.add('ats-classic');
    }
    if (hit(['管理', '市场', '公关', '文案'])) {
      out.add('elegant-serif');
    }
    return out;
  }

  static final Map<String, ResumeTemplate> _byIdMap = {
    for (final t in _all) t.id: t,
  };

  /// 各模板的章节优先级关键词（命中越靠前越先渲染）。
  static const Map<String, List<String>> _priority = {
    'academic-cv': ['publication', 'research', '论文', '科研', '研究', 'education', '教育', 'experience', '项目', 'award'],
    'fresh-graduate': ['education', '教育', 'project', '项目', 'experience', '实习', 'skill', '技能', 'award', 'certificate'],
    'teacher': ['education', '教育', 'certificate', '资格', '证书', 'experience', '教学', '教研', 'skill', 'award'],
    'tech-compact': ['skill', '技能', 'tech', '技术', 'project', '项目', 'experience', '工作', 'education', '教育'],
    'business': ['experience', '工作', '经历', 'skill', '技能', 'education', '教育', 'certificate', '证书', 'award'],
    'ats-classic': ['experience', '工作', '经历', 'education', '教育', 'skill', '技能', 'project', '项目'],
  };

  /// 按模板重排章节（不改变原列表；无优先级或缺省时原样返回）。
  static List<ResumeSection> orderSections(
    List<ResumeSection> sections,
    String? templateId,
  ) {
    final order = _priority[byId(templateId).id];
    if (order == null || sections.length < 2) return sections;
    int rank(ResumeSection s) {
      final hay = '${s.key} ${s.title}'.toLowerCase();
      for (var i = 0; i < order.length; i++) {
        if (hay.contains(order[i].toLowerCase())) return i;
      }
      return order.length + 1;
    }

    final indexed = <MapEntry<int, ResumeSection>>[
      for (var i = 0; i < sections.length; i++) MapEntry(i, sections[i]),
    ];
    indexed.sort((a, b) {
      final d = rank(a.value).compareTo(rank(b.value));
      return d != 0 ? d : a.key.compareTo(b.key);
    });
    return [for (final e in indexed) e.value];
  }
}
