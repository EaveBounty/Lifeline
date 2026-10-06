/// 岗位画像库：为「岗位适配诊断」提供硬性证书、核心技能、典型经历、
/// 加分项与「提升录取概率」的行动/资源。
///
/// 纯数据、离线、确定性；[RoleProfiles.match] 按别名/关键词子串匹配目标岗位。
library;

/// 岗位行动建议。
class RoleAction {
  final String action;

  /// cert | experience | skill | education | portfolio | other。
  final String category;

  /// 预估录取概率提升（0–100）。
  final int expectedGain;

  /// low | medium | high。
  final String effort;
  final String timeEstimate;
  final String rationale;
  final List<String> resources;

  const RoleAction({
    required this.action,
    this.category = 'other',
    this.expectedGain = 0,
    this.effort = 'medium',
    this.timeEstimate = '',
    this.rationale = '',
    this.resources = const [],
  });
}

/// 一个岗位/方向的画像。
class RoleProfile {
  final String id;
  final String name;
  final List<String> aliases;

  /// 必备/加分证书（mandatory=true 为硬性要求）。
  final List<({String name, bool mandatory})> requiredCerts;
  final List<String> coreSkills;
  final List<String> typicalExperiences;
  final List<String> bonusItems;
  final List<RoleAction> actions;

  const RoleProfile({
    required this.id,
    required this.name,
    required this.aliases,
    this.requiredCerts = const [],
    this.coreSkills = const [],
    this.typicalExperiences = const [],
    this.bonusItems = const [],
    this.actions = const [],
  });
}

/// 画像库入口。
class RoleProfiles {
  RoleProfiles._();

  static List<RoleProfile> get all => _all;

  /// 按 targetRole 文本匹配画像；大小写/中英不敏感；无匹配返回 null。
  static RoleProfile? match(String? roleText) {
    final text = (roleText ?? '').trim().toLowerCase();
    if (text.isEmpty) return null;
    for (final p in _all) {
      for (final a in p.aliases) {
        final alias = a.toLowerCase().trim();
        if (alias.isEmpty) continue;
        if (_isShortAscii(alias)) {
          if (_containsToken(text, alias)) return p;
        } else if (text.contains(alias)) {
          return p;
        }
      }
    }
    return null;
  }

  static bool _isShortAscii(String s) =>
      s.length <= 3 && s.codeUnits.every((c) => c < 128);

  static bool _containsToken(String hay, String token) =>
      hay.split(RegExp(r'[^a-z0-9+#]+')).contains(token);
}

final List<RoleProfile> _all = const [
  // 1. 教师
  RoleProfile(
    id: 'teacher',
    name: '教师',
    aliases: ['教师', '老师', '教育', '教研', '讲师', 'teacher', '教资', '特岗', '师范'],
    requiredCerts: [
      (name: '教师资格证', mandatory: true),
      (name: '普通话等级证', mandatory: true),
    ],
    coreSkills: ['备课', '课堂教学', '班级管理', '学情分析', '教学设计', '学科专业知识', '教育心理学', '多媒体教学', '家校沟通'],
    typicalExperiences: ['教育实习', '支教/顶岗', '班主任工作', '教学技能大赛', '家教/辅导'],
    bonusItems: ['师范专业', '双一流院校', '竞赛辅导获奖', '论文/课题', '心理咨询师'],
    actions: [
      RoleAction(
        action: '报名中小学教师资格考试（NTCE）',
        category: 'cert',
        expectedGain: 40,
        effort: 'low',
        timeEstimate: '3–6 个月',
        rationale: '教师资格证是教师岗最硬的准入门槛，缺失几乎无法通过资格审查。',
        resources: ['https://ntce.neea.edu.cn'],
      ),
      RoleAction(
        action: '考取普通话水平等级证书',
        category: 'cert',
        expectedGain: 15,
        effort: 'low',
        timeEstimate: '1–2 个月',
        rationale: '语文/幼儿教师通常要求二级甲等及以上，是认定教师资格的必要条件。',
        resources: ['http://www.cltt.org'],
      ),
      RoleAction(
        action: '参加师范生教学技能大赛',
        category: 'skill',
        expectedGain: 12,
        effort: 'medium',
        timeEstimate: '2–3 个月',
        rationale: '省级以上教学技能奖项是教学能力的强证据，面试说课有明显加成。',
      ),
      RoleAction(
        action: '争取教育实习/支教经历',
        category: 'experience',
        expectedGain: 18,
        effort: 'medium',
        timeEstimate: '3–6 个月',
        rationale: '真实课堂经历直接回应「能否站稳讲台」，是招聘方最看重的证据。',
      ),
      RoleAction(
        action: '研读新课标与教材教法',
        category: 'skill',
        expectedGain: 10,
        effort: 'low',
        timeEstimate: '2–4 周',
        rationale: '笔试与说课均围绕新课标命题，系统准备性价比高。',
      ),
      RoleAction(
        action: '准备教师招聘笔试与说课试讲',
        category: 'skill',
        expectedGain: 20,
        effort: 'high',
        timeEstimate: '3–6 个月',
        rationale: '教育综合知识 + 学科专业 + 说课/试讲是上岸核心环节。',
      ),
    ],
  ),

  // 2. 算法 / 机器学习
  RoleProfile(
    id: 'algorithm',
    name: '算法/机器学习',
    aliases: ['算法工程师', '算法岗', '机器学习', '深度学习', '数据挖掘', '人工智能', 'ai工程师', 'algorithm', '机器学习工程师', 'nlp', 'cv工程师', '大模型', 'llm'],
    coreSkills: ['Python', 'PyTorch/TensorFlow', '机器学习', '深度学习', '数据结构与算法', 'SQL', '模型评估', '特征工程', 'Linux/Git'],
    typicalExperiences: ['竞赛（Kaggle/天池）', '算法实习', '论文/复现', '开源项目', '模型上线'],
    bonusItems: ['顶会论文', '竞赛名次', '大厂实习', 'Kaggle 奖牌', 'GitHub Star'],
    actions: [
      RoleAction(
        action: '参加 Kaggle 竞赛并冲击奖牌',
        category: 'portfolio',
        expectedGain: 15,
        effort: 'medium',
        timeEstimate: '1–3 个月',
        rationale: 'Kaggle 排名是可量化的建模能力背书，简历辨识度高。',
        resources: ['https://www.kaggle.com'],
      ),
      RoleAction(
        action: '参加天池/DataFountain 等国内竞赛',
        category: 'portfolio',
        expectedGain: 12,
        effort: 'medium',
        timeEstimate: '1–3 个月',
        rationale: '国内竞赛名次对校招算法岗认可度高，且贴合企业真实题目。',
        resources: ['https://tianchi.aliyun.com'],
      ),
      RoleAction(
        action: '刷 LeetCode 算法题（Hot 100 / 剑指 Offer）',
        category: 'skill',
        expectedGain: 12,
        effort: 'low',
        timeEstimate: '1–3 个月',
        rationale: '笔试与一面几乎必考手撕算法，刷题是最直接的通过率提升。',
        resources: ['https://leetcode.cn'],
      ),
      RoleAction(
        action: '构建 GitHub 开源/论文复现项目',
        category: 'portfolio',
        expectedGain: 15,
        effort: 'medium',
        timeEstimate: '1–3 个月',
        rationale: '可运行的代码与复现结果比课程作业更能证明工程与建模能力。',
        resources: ['https://github.com'],
      ),
      RoleAction(
        action: '争取算法岗实习（大厂/实验室）',
        category: 'experience',
        expectedGain: 25,
        effort: 'high',
        timeEstimate: '3–6 个月',
        rationale: '相关实习经历是校招算法岗最强的筛选信号与转正通道。',
      ),
      RoleAction(
        action: '阅读并复现顶会论文',
        category: 'skill',
        expectedGain: 10,
        effort: 'high',
        timeEstimate: '2–4 个月',
        rationale: '论文复现体现研究潜力，对研究型算法岗加分明显。',
        resources: ['https://arxiv.org'],
      ),
      RoleAction(
        action: '补充 SQL 与大数据处理技能',
        category: 'skill',
        expectedGain: 8,
        effort: 'low',
        timeEstimate: '2–4 周',
        rationale: '特征/样本处理离不开 SQL 与数据管道，是常见笔试考点。',
      ),
    ],
  ),

  // 3. 软件开发
  RoleProfile(
    id: 'software',
    name: '软件开发',
    aliases: ['软件工程师', '后端', '前端', '全栈', '开发工程师', '程序员', '软件开发', 'java开发', 'golang开发', 'c++开发', 'web开发', '移动开发', 'ios开发', 'android开发', '测试工程师', 'sre', 'devops'],
    coreSkills: ['数据结构与算法', '一门主力语言', 'Git', '数据库(SQL)', '操作系统/网络', 'Linux', '主流框架', '单元测试', 'CI/CD'],
    typicalExperiences: ['后端/前端项目', '开源贡献', '实习', '技术博客', '线上问题排查'],
    bonusItems: ['大厂实习', '开源项目', '技术竞赛', '博客/Star', '系统设计能力'],
    actions: [
      RoleAction(
        action: '打磨 1–2 个高质量项目并写清技术难点',
        category: 'portfolio',
        expectedGain: 18,
        effort: 'medium',
        timeEstimate: '1–3 个月',
        rationale: '项目是开发岗的核心证据，需体现架构取舍与量化结果。',
        resources: ['https://github.com'],
      ),
      RoleAction(
        action: '刷算法题（LeetCode / 牛客）',
        category: 'skill',
        expectedGain: 15,
        effort: 'low',
        timeEstimate: '2–3 个月',
        rationale: '笔试与面试手撕算法是硬门槛，刷题投入产出比最高。',
        resources: ['https://leetcode.cn', 'https://www.nowcoder.com'],
      ),
      RoleAction(
        action: '争取软件开发实习',
        category: 'experience',
        expectedGain: 25,
        effort: 'high',
        timeEstimate: '3–6 个月',
        rationale: '相关实习是校招最有效的敲门砖，并可直接转正。',
      ),
      RoleAction(
        action: '参与开源项目并提交 PR',
        category: 'portfolio',
        expectedGain: 12,
        effort: 'medium',
        timeEstimate: '1–3 个月',
        rationale: '开源贡献体现协作与代码质量，是差异化亮点。',
        resources: ['https://github.com'],
      ),
      RoleAction(
        action: '系统复习计算机基础与系统设计',
        category: 'skill',
        expectedGain: 15,
        effort: 'high',
        timeEstimate: '2–4 个月',
        rationale: '操作系统/网络/系统设计是中高级岗位的分水岭。',
      ),
      RoleAction(
        action: '维护技术博客/作品集',
        category: 'portfolio',
        expectedGain: 8,
        effort: 'low',
        timeEstimate: '长期',
        rationale: '持续输出提升可信度与个人品牌。',
      ),
    ],
  ),

  // 4. 数据分析
  RoleProfile(
    id: 'data_analysis',
    name: '数据分析',
    aliases: ['数据分析', '数据分析师', '数据科学', '商业分析', '数据工程师', 'bi工程师', 'data analyst', '数据运营', '商业分析师'],
    coreSkills: ['SQL', 'Excel', 'Python/R', 'BI 工具(Tableau/PowerBI)', '统计与概率', '数据可视化', '业务理解', 'A/B 测试'],
    typicalExperiences: ['分析报告', '数据看板', '业务增长分析', '数据清洗项目', '实习'],
    bonusItems: ['业务落地案例', '行业理解', 'SQL 优化', '机器学习基础'],
    actions: [
      RoleAction(
        action: '系统练习 SQL（窗口函数/优化）',
        category: 'skill',
        expectedGain: 20,
        effort: 'low',
        timeEstimate: '1–2 个月',
        rationale: 'SQL 是数据分析笔试面试的第一考点，投入小见效快。',
        resources: ['https://leetcode.cn', 'https://sqlzoo.net'],
      ),
      RoleAction(
        action: '用真实数据集做分析作品集',
        category: 'portfolio',
        expectedGain: 18,
        effort: 'medium',
        timeEstimate: '1–2 个月',
        rationale: '从取数到结论的完整案例最能证明业务分析能力。',
        resources: ['https://www.kaggle.com'],
      ),
      RoleAction(
        action: '学习 BI 可视化工具',
        category: 'skill',
        expectedGain: 12,
        effort: 'low',
        timeEstimate: '2–4 周',
        rationale: 'Tableau/PowerBI 是岗位 JD 高频工具词。',
        resources: ['https://www.tableau.com', 'https://powerbi.microsoft.com'],
      ),
      RoleAction(
        action: '争取数据分析实习',
        category: 'experience',
        expectedGain: 22,
        effort: 'high',
        timeEstimate: '3–6 个月',
        rationale: '真实业务实习是转行/校招的关键背书。',
      ),
      RoleAction(
        action: '补充统计与 A/B 测试知识',
        category: 'skill',
        expectedGain: 12,
        effort: 'medium',
        timeEstimate: '1 个月',
        rationale: '实验设计是数据驱动决策的核心方法。',
      ),
      RoleAction(
        action: '学习 Python 数据分析库（pandas 等）',
        category: 'skill',
        expectedGain: 10,
        effort: 'low',
        timeEstimate: '2–4 周',
        rationale: 'pandas 是数据清洗与分析的必备工具。',
      ),
    ],
  ),

  // 5. 产品经理
  RoleProfile(
    id: 'product_manager',
    name: '产品经理',
    aliases: ['产品经理', '产品岗', '产品助理', 'product manager', '产品设计'],
    requiredCerts: [],
    coreSkills: ['需求分析', '原型(Axure/Figma)', 'PRD 撰写', '数据指标', '用户研究', '项目管理', '沟通协调', '竞品分析'],
    typicalExperiences: ['产品/功能设计', '需求文档', '数据驱动迭代', '跨部门协作', '实习'],
    bonusItems: ['上线产品案例', '数据增长成果', '行业经验', '技术背景'],
    actions: [
      RoleAction(
        action: '完成一份产品分析/竞品拆解报告',
        category: 'portfolio',
        expectedGain: 15,
        effort: 'low',
        timeEstimate: '1–2 周',
        rationale: '可直接展示产品思维与结构化表达，作品集门槛低。',
      ),
      RoleAction(
        action: '学习原型工具与 PRD 撰写',
        category: 'skill',
        expectedGain: 12,
        effort: 'low',
        timeEstimate: '2–4 周',
        rationale: 'Axure/Figma 与 PRD 是产品岗的通用工作语言。',
        resources: ['https://www.figma.com'],
      ),
      RoleAction(
        action: '争取产品经理实习',
        category: 'experience',
        expectedGain: 25,
        effort: 'high',
        timeEstimate: '3–6 个月',
        rationale: '产品岗高度看经验，实习是最有效的入口。',
      ),
      RoleAction(
        action: '补充数据分析能力',
        category: 'skill',
        expectedGain: 12,
        effort: 'medium',
        timeEstimate: '1 个月',
        rationale: '用数据验证需求与衡量迭代效果是产品岗硬技能。',
      ),
      RoleAction(
        action: '参与校园/创业产品项目',
        category: 'experience',
        expectedGain: 15,
        effort: 'medium',
        timeEstimate: '2–6 个月',
        rationale: '完整上线案例比纸面报告更有说服力。',
      ),
      RoleAction(
        action: '系统学习产品方法论',
        category: 'skill',
        expectedGain: 10,
        effort: 'low',
        timeEstimate: '1 个月',
        rationale: '建立需求优先级/用户旅程等框架，面试表达更专业。',
      ),
    ],
  ),

  // 6. 金融 / 会计
  RoleProfile(
    id: 'finance',
    name: '金融/会计',
    aliases: ['金融', '会计', '财务', '审计', '银行', '券商', '投行', '量化', 'quant', '基金', '保险', 'cpa', 'acca', '证券'],
    requiredCerts: [
      (name: '初级会计职称', mandatory: false),
      (name: '证券/基金从业资格', mandatory: false),
      (name: 'CPA', mandatory: false),
      (name: 'CFA', mandatory: false),
    ],
    coreSkills: ['财务会计', '财务报表分析', 'Excel/建模', '估值', '税务', '审计准则', 'Wind/Choice', '经济学基础'],
    typicalExperiences: ['事务所/券商/银行实习', '财务/审计项目', '建模竞赛', '研究报告'],
    bonusItems: ['CPA/CFA 通过科目', '事务所实习', '数学建模获奖', 'Python 数据分析'],
    actions: [
      RoleAction(
        action: '备考初级会计职称/证券基金从业资格',
        category: 'cert',
        expectedGain: 20,
        effort: 'medium',
        timeEstimate: '1–3 个月',
        rationale: '从业类证书是金融基础岗的常见硬门槛或加分项。',
        resources: ['http://kzp.mof.gov.cn', 'https://www.sac.net.cn'],
      ),
      RoleAction(
        action: '争取事务所/券商/银行实习',
        category: 'experience',
        expectedGain: 25,
        effort: 'high',
        timeEstimate: '3–6 个月',
        rationale: '金融机构招聘高度看实习背景，是简历筛选关键。',
      ),
      RoleAction(
        action: '练习财务建模与 Excel',
        category: 'skill',
        expectedGain: 12,
        effort: 'low',
        timeEstimate: '1 个月',
        rationale: '估值/建模是投研与投行岗的高频考核点。',
      ),
      RoleAction(
        action: '系统学习财务报表分析',
        category: 'skill',
        expectedGain: 12,
        effort: 'medium',
        timeEstimate: '1–2 个月',
        rationale: '三张表分析与比率解读是财务岗基本功。',
      ),
      RoleAction(
        action: '参加数学建模/案例分析大赛',
        category: 'portfolio',
        expectedGain: 10,
        effort: 'medium',
        timeEstimate: '1–3 个月',
        rationale: '竞赛奖项可佐证量化与商业分析能力。',
      ),
      RoleAction(
        action: '考取 CPA/CFA（部分科目）',
        category: 'cert',
        expectedGain: 18,
        effort: 'high',
        timeEstimate: '6–18 个月',
        rationale: '高含金量证书显著提升长期竞争力与起薪。',
      ),
    ],
  ),

  // 7. 公务员 / 事业编
  RoleProfile(
    id: 'civil_servant',
    name: '公务员/事业编',
    aliases: ['公务员', '事业编', '事业单位', '选调', '国考', '省考', '体制内', '公考', '选调生', '编制'],
    requiredCerts: [],
    coreSkills: ['行测', '申论', '公共基础知识', '时政', '公文写作', '结构化面试', '政策理解'],
    typicalExperiences: ['公考备考', '基层实践', '学生干部', '志愿活动', '调研报告'],
    bonusItems: ['党员', '学生干部', '基层经历', '专业对口', '资格证书'],
    actions: [
      RoleAction(
        action: '系统备考行测（分模块刷题）',
        category: 'skill',
        expectedGain: 25,
        effort: 'high',
        timeEstimate: '3–6 个月',
        rationale: '行测是笔试拉开分差的关键，题量与方法并重。',
        resources: ['http://www.gjgwy.org'],
      ),
      RoleAction(
        action: '练习申论写作与材料概括',
        category: 'skill',
        expectedGain: 20,
        effort: 'medium',
        timeEstimate: '2–4 个月',
        rationale: '申论主观分差距大，需长期积累规范表达。',
      ),
      RoleAction(
        action: '关注招考公告与职位表筛选',
        category: 'other',
        expectedGain: 15,
        effort: 'low',
        timeEstimate: '持续',
        rationale: '岗位选择与竞争比直接影响上岸概率，「考得好不如报得好」。',
        resources: ['http://www.scs.gov.cn'],
      ),
      RoleAction(
        action: '准备结构化面试',
        category: 'skill',
        expectedGain: 15,
        effort: 'high',
        timeEstimate: '1–2 个月',
        rationale: '面试占比高，需大量模拟与表达训练。',
      ),
      RoleAction(
        action: '参加基层实践/志愿服务',
        category: 'experience',
        expectedGain: 10,
        effort: 'medium',
        timeEstimate: '1–6 个月',
        rationale: '基层经历与政治面貌在部分岗位有加分或定向优势。',
      ),
      RoleAction(
        action: '准备事业单位专业科目',
        category: 'skill',
        expectedGain: 12,
        effort: 'medium',
        timeEstimate: '1–3 个月',
        rationale: '事业编常考岗位相关专业知识，需针对性复习。',
      ),
    ],
  ),

  // 8. 医生 / 护理
  RoleProfile(
    id: 'doctor',
    name: '医生/护理',
    aliases: ['医生', '医师', '护理', '护士', '临床', '医学', '药师', '公共卫生', '规培', '住院医师', '检验师'],
    requiredCerts: [
      (name: '执业医师资格证', mandatory: true),
      (name: '执业护士资格证', mandatory: true),
      (name: '住院医师规范化培训合格证', mandatory: false),
    ],
    coreSkills: ['临床医学知识', '诊断思维', '病历书写', '基础/临床操作', '医患沟通', '急救(CPR)', '循证医学'],
    typicalExperiences: ['临床实习/见习', '规培', '科研/论文', '值班轮转', '志愿服务'],
    bonusItems: ['科研论文', '专科证书', '三甲实习', '党员', '急救证书'],
    actions: [
      RoleAction(
        action: '通过执业医师/护士资格考试',
        category: 'cert',
        expectedGain: 35,
        effort: 'high',
        timeEstimate: '6–12 个月',
        rationale: '执业资格是从医的法定前提，缺失无法独立执业。',
        resources: ['http://www.nmec.org.cn'],
      ),
      RoleAction(
        action: '完成住院医师规范化培训',
        category: 'cert',
        expectedGain: 20,
        effort: 'high',
        timeEstimate: '≥3 年',
        rationale: '规培证是进入公立医院临床岗位的硬性条件。',
      ),
      RoleAction(
        action: '争取三甲医院实习/规培',
        category: 'experience',
        expectedGain: 25,
        effort: 'high',
        timeEstimate: '6–12 个月',
        rationale: '三甲平台经历显著提升临床与求职竞争力。',
      ),
      RoleAction(
        action: '参与科研并发表论文',
        category: 'portfolio',
        expectedGain: 12,
        effort: 'high',
        timeEstimate: '6–12 个月',
        rationale: '论文是职称晋升与三甲招聘的重要加分。',
      ),
      RoleAction(
        action: '练习病历书写与临床操作技能',
        category: 'skill',
        expectedGain: 12,
        effort: 'medium',
        timeEstimate: '1–3 个月',
        rationale: '病历与操作是实习考核与面试的常见考点。',
      ),
      RoleAction(
        action: '考取急救/专科证书',
        category: 'cert',
        expectedGain: 8,
        effort: 'low',
        timeEstimate: '2–4 周',
        rationale: 'CPR 等急救证书提升临床可信度。',
      ),
    ],
  ),

  // 9. 律师 / 法务
  RoleProfile(
    id: 'lawyer',
    name: '律师/法务',
    aliases: ['律师', '法务', '法律', '法考', '法律顾问', '合规', '诉讼', '律所'],
    requiredCerts: [
      (name: '法律职业资格证', mandatory: true),
    ],
    coreSkills: ['法律检索', '合同审查', '法律文书', '诉讼流程', '合规', '逻辑论证', '英语'],
    typicalExperiences: ['律所/法院/法务实习', '模拟法庭', '法律援助', '合同审核'],
    bonusItems: ['法考通过', '知名律所实习', '英语/涉外', '发表文章'],
    actions: [
      RoleAction(
        action: '通过法律职业资格考试（法考）',
        category: 'cert',
        expectedGain: 35,
        effort: 'high',
        timeEstimate: '6–12 个月',
        rationale: '法考是律师/法务职业的准入门槛，含金量极高。',
        resources: ['https://www.moj.gov.cn'],
      ),
      RoleAction(
        action: '争取律所/法院/企业法务实习',
        category: 'experience',
        expectedGain: 25,
        effort: 'high',
        timeEstimate: '3–6 个月',
        rationale: '实务实习是法律求职的核心筛选依据。',
      ),
      RoleAction(
        action: '练习合同审查与法律文书写作',
        category: 'skill',
        expectedGain: 15,
        effort: 'medium',
        timeEstimate: '1–2 个月',
        rationale: '合同与文书是法务日常工作主体，可直接作为作品。',
      ),
      RoleAction(
        action: '法律检索与案例研习',
        category: 'skill',
        expectedGain: 10,
        effort: 'low',
        timeEstimate: '持续',
        rationale: '熟练使用法规/案例数据库是基本功。',
      ),
      RoleAction(
        action: '参加模拟法庭/法律援助',
        category: 'portfolio',
        expectedGain: 10,
        effort: 'medium',
        timeEstimate: '1–3 个月',
        rationale: '实战演练体现庭审与辩论能力。',
      ),
      RoleAction(
        action: '提升英语（涉外法务方向）',
        category: 'skill',
        expectedGain: 8,
        effort: 'medium',
        timeEstimate: '3–6 个月',
        rationale: '涉外业务对英语要求高，是差异化方向。',
      ),
    ],
  ),

  // 10. 设计 / UI
  RoleProfile(
    id: 'design_ui',
    name: '设计/UI',
    aliases: ['ui', 'ux', '视觉设计师', '交互设计师', '平面设计', '设计师', 'ui设计', 'ux设计', '工业设计', '设计'],
    requiredCerts: [],
    coreSkills: ['Figma/Sketch', '设计规范', '视觉排版', '交互原型', '用户研究', '动效', '配色', '切图交付'],
    typicalExperiences: ['作品集项目', '设计比赛', '实习', '改版案例', '品牌/视觉项目'],
    bonusItems: ['获奖作品', '大厂实习', '跨端经验', '数据驱动改版'],
    actions: [
      RoleAction(
        action: '打磨高质量作品集（3–5 个完整案例）',
        category: 'portfolio',
        expectedGain: 25,
        effort: 'high',
        timeEstimate: '1–3 个月',
        rationale: '作品集是设计岗的第一筛选标准，质量决定面试机会。',
        resources: ['https://www.behance.net', 'https://www.zcool.com.cn'],
      ),
      RoleAction(
        action: '精进 Figma 与设计系统能力',
        category: 'skill',
        expectedGain: 15,
        effort: 'medium',
        timeEstimate: '1–2 个月',
        rationale: '组件化/设计系统是中高级设计岗的高频要求。',
        resources: ['https://www.figma.com'],
      ),
      RoleAction(
        action: '参加设计比赛并投稿',
        category: 'portfolio',
        expectedGain: 12,
        effort: 'medium',
        timeEstimate: '1–3 个月',
        rationale: '获奖或入围可快速提升作品集权重。',
      ),
      RoleAction(
        action: '争取设计实习',
        category: 'experience',
        expectedGain: 22,
        effort: 'high',
        timeEstimate: '3–6 个月',
        rationale: '真实项目经验与团队协作是招聘方关注点。',
      ),
      RoleAction(
        action: '学习用户研究与交互方法',
        category: 'skill',
        expectedGain: 12,
        effort: 'medium',
        timeEstimate: '1 个月',
        rationale: '能从用户与数据出发的设计更受青睐。',
      ),
      RoleAction(
        action: '上传站酷/Behance 积累曝光',
        category: 'portfolio',
        expectedGain: 8,
        effort: 'low',
        timeEstimate: '长期',
        rationale: '公开作品带来曝光与被发现的机会。',
        resources: ['https://www.zcool.com.cn'],
      ),
    ],
  ),

  // 11. 销售
  RoleProfile(
    id: 'sales',
    name: '销售',
    aliases: ['销售', 'sales', '客户经理', '商务', 'bd', '渠道', '大客户', '销售代表'],
    requiredCerts: [],
    coreSkills: ['沟通谈判', '客户开发', 'CRM', '产品知识', '目标管理', '抗压', '方案演示'],
    typicalExperiences: ['销售实习', '校园代理', '社团外联', '业绩达成', '客户维护'],
    bonusItems: ['业绩数据', '大客户资源', '行业经验', '驾照'],
    actions: [
      RoleAction(
        action: '补充可量化的销售业绩数据',
        category: 'other',
        expectedGain: 20,
        effort: 'low',
        timeEstimate: '1 天',
        rationale: '销售岗最看重结果数字，量化业绩直接提升说服力。',
      ),
      RoleAction(
        action: '争取销售/商务实习',
        category: 'experience',
        expectedGain: 25,
        effort: 'high',
        timeEstimate: '3–6 个月',
        rationale: '实战业绩是销售岗最强背书。',
      ),
      RoleAction(
        action: '练习沟通表达与谈判技巧',
        category: 'skill',
        expectedGain: 12,
        effort: 'medium',
        timeEstimate: '1 个月',
        rationale: '沟通谈判是销售核心能力，可通过模拟与复盘提升。',
      ),
      RoleAction(
        action: '学习 CRM 与销售方法论',
        category: 'skill',
        expectedGain: 10,
        effort: 'low',
        timeEstimate: '2–4 周',
        rationale: '掌握漏斗/跟进等流程化方法，面试更专业。',
      ),
      RoleAction(
        action: '参与校园代理/外联项目',
        category: 'experience',
        expectedGain: 12,
        effort: 'medium',
        timeEstimate: '1–6 个月',
        rationale: '低门槛获取可量化业绩与客户开发经验。',
      ),
      RoleAction(
        action: '考取驾照',
        category: 'other',
        expectedGain: 5,
        effort: 'low',
        timeEstimate: '1–3 个月',
        rationale: '部分销售岗需外出拜访，驾照是隐性要求。',
      ),
    ],
  ),

  // 12. 市场
  RoleProfile(
    id: 'marketing',
    name: '市场',
    aliases: ['市场', 'marketing', '品牌', '公关', '推广', '市场专员', '整合营销', '品牌经理'],
    requiredCerts: [],
    coreSkills: ['市场调研', '文案策划', '活动执行', '数据分析', '社媒运营', 'SEO/SEM', '品牌传播', 'PPT'],
    typicalExperiences: ['campaign 策划', '市场调研报告', '活动执行', '实习', '新媒体运营'],
    bonusItems: ['爆款案例', '数据成果', '跨部门协作', '英语'],
    actions: [
      RoleAction(
        action: '完成一份市场调研/整合营销策划案',
        category: 'portfolio',
        expectedGain: 18,
        effort: 'medium',
        timeEstimate: '2–4 周',
        rationale: '策划案可直接展示市场分析与创意能力。',
      ),
      RoleAction(
        action: '运营个人/校园社媒账号',
        category: 'portfolio',
        expectedGain: 15,
        effort: 'low',
        timeEstimate: '1–3 个月',
        rationale: '可量化的内容增长数据是市场岗的有力证据。',
      ),
      RoleAction(
        action: '争取市场/品牌实习',
        category: 'experience',
        expectedGain: 25,
        effort: 'high',
        timeEstimate: '3–6 个月',
        rationale: '真实 campaign 经验是市场岗筛选关键。',
      ),
      RoleAction(
        action: '学习数据分析与广告投放',
        category: 'skill',
        expectedGain: 12,
        effort: 'medium',
        timeEstimate: '1 个月',
        rationale: '投放 ROI/转化分析是市场岗核心技能。',
      ),
      RoleAction(
        action: '参加营销/商业策划大赛',
        category: 'portfolio',
        expectedGain: 10,
        effort: 'medium',
        timeEstimate: '1–3 个月',
        rationale: '竞赛奖项提升简历竞争力。',
      ),
      RoleAction(
        action: '打磨文案与 PPT 表达能力',
        category: 'skill',
        expectedGain: 8,
        effort: 'low',
        timeEstimate: '2–4 周',
        rationale: '市场岗高频输出方案与物料，表达能力重要。',
      ),
    ],
  ),

  // 13. 运营
  RoleProfile(
    id: 'operations',
    name: '运营',
    aliases: ['运营', '新媒体运营', '内容运营', '用户运营', '活动运营', '社群运营', '电商运营', '增长运营'],
    requiredCerts: [],
    coreSkills: ['内容策划', '用户增长', '数据复盘', '活动运营', '社群维护', '文案', 'Excel', '平台规则'],
    typicalExperiences: ['账号运营', '活动策划', '增长项目', '用户调研', '电商店铺运营'],
    bonusItems: ['数据增长案例', '爆款内容', '私域经验', '工具使用'],
    actions: [
      RoleAction(
        action: '从 0 运营一个真实账号并记录数据',
        category: 'portfolio',
        expectedGain: 20,
        effort: 'low',
        timeEstimate: '1–3 个月',
        rationale: '可量化的涨粉/转化数据是运营岗最直接的证明。',
      ),
      RoleAction(
        action: '学习数据复盘与用户增长方法',
        category: 'skill',
        expectedGain: 15,
        effort: 'medium',
        timeEstimate: '1 个月',
        rationale: '留存/漏斗/AB 测试是运营进阶的核心方法。',
      ),
      RoleAction(
        action: '争取运营实习',
        category: 'experience',
        expectedGain: 25,
        effort: 'high',
        timeEstimate: '3–6 个月',
        rationale: '真实项目的增长结果最能体现运营能力。',
      ),
      RoleAction(
        action: '研究目标平台算法与规则',
        category: 'skill',
        expectedGain: 10,
        effort: 'low',
        timeEstimate: '持续',
        rationale: '理解平台分发逻辑是内容运营的基础。',
      ),
      RoleAction(
        action: '参与校园/增长类项目',
        category: 'experience',
        expectedGain: 12,
        effort: 'medium',
        timeEstimate: '1–6 个月',
        rationale: '积累可讲述的活动与增长案例。',
      ),
      RoleAction(
        action: '打磨文案与内容创作',
        category: 'skill',
        expectedGain: 8,
        effort: 'low',
        timeEstimate: '长期',
        rationale: '内容质量是运营效果的底层变量。',
      ),
    ],
  ),

  // 14. 人力 HR
  RoleProfile(
    id: 'hr',
    name: '人力 HR',
    aliases: ['人力资源', 'hr', '招聘', '人事', '人力', '培训', '组织发展', 'od', 'hrbp'],
    requiredCerts: [
      (name: '人力资源管理师', mandatory: false),
    ],
    coreSkills: ['招聘流程', '简历筛选', '面试技巧', '劳动法', '沟通协调', 'Excel', 'HRBP 思维', '培训设计'],
    typicalExperiences: ['招聘实习', '校园招聘组织', '社团管理', '培训项目', '员工关系'],
    bonusItems: ['人力资源管理师证书', '大厂实习', '劳动法知识', '数据分析'],
    actions: [
      RoleAction(
        action: '考取人力资源管理师',
        category: 'cert',
        expectedGain: 15,
        effort: 'medium',
        timeEstimate: '1–3 个月',
        rationale: '从业类证书是 HR 岗的常见加分项。',
      ),
      RoleAction(
        action: '争取 HR 实习（招聘方向）',
        category: 'experience',
        expectedGain: 25,
        effort: 'high',
        timeEstimate: '3–6 个月',
        rationale: '招聘实习最易切入且直接体现 HR 核心能力。',
      ),
      RoleAction(
        action: '学习劳动法与用工合规',
        category: 'skill',
        expectedGain: 12,
        effort: 'low',
        timeEstimate: '2–4 周',
        rationale: '用工合规是 HR 的底线能力，面试常考。',
      ),
      RoleAction(
        action: '组织校园招聘/培训活动',
        category: 'experience',
        expectedGain: 12,
        effort: 'medium',
        timeEstimate: '1–3 个月',
        rationale: '完整组织一次招聘/培训流程是强证据。',
      ),
      RoleAction(
        action: '练习面试与沟通',
        category: 'skill',
        expectedGain: 10,
        effort: 'low',
        timeEstimate: '持续',
        rationale: 'HR 需高频与人打交道，沟通评估能力关键。',
      ),
      RoleAction(
        action: '学习 Excel 与人力数据分析',
        category: 'skill',
        expectedGain: 8,
        effort: 'low',
        timeEstimate: '2–4 周',
        rationale: '人力数据分析越来越受重视。',
      ),
    ],
  ),

  // 15. 行政
  RoleProfile(
    id: 'admin',
    name: '行政',
    aliases: ['行政', '文员', '秘书', '行政助理', '办公室主任', '后勤', '行政专员'],
    requiredCerts: [],
    coreSkills: ['公文写作', '办公软件', '会务组织', '沟通协调', '档案管理', '时间管理', '细节把控'],
    typicalExperiences: ['办公室实习', '会议/活动组织', '文件归档', '学生干部', '行政支持'],
    bonusItems: ['驾照', '党员', '公文写作经验', '英语'],
    actions: [
      RoleAction(
        action: '提升办公软件与公文写作',
        category: 'skill',
        expectedGain: 18,
        effort: 'low',
        timeEstimate: '2–4 周',
        rationale: '公文与 Office 是行政岗的核心工作技能。',
      ),
      RoleAction(
        action: '争取行政/秘书实习',
        category: 'experience',
        expectedGain: 22,
        effort: 'high',
        timeEstimate: '3–6 个月',
        rationale: '办公室实务经验是行政岗筛选关键。',
      ),
      RoleAction(
        action: '组织会务/活动',
        category: 'experience',
        expectedGain: 12,
        effort: 'medium',
        timeEstimate: '1–3 个月',
        rationale: '会务组织体现统筹与细节把控能力。',
      ),
      RoleAction(
        action: '学习档案与流程管理',
        category: 'skill',
        expectedGain: 10,
        effort: 'low',
        timeEstimate: '1 个月',
        rationale: '规范流程与档案管理是行政进阶能力。',
      ),
      RoleAction(
        action: '考取驾照',
        category: 'other',
        expectedGain: 5,
        effort: 'low',
        timeEstimate: '1–3 个月',
        rationale: '部分行政岗需外出办事，驾照是隐性优势。',
      ),
      RoleAction(
        action: '补充学生干部/组织经历',
        category: 'experience',
        expectedGain: 10,
        effort: 'medium',
        timeEstimate: '长期',
        rationale: '组织协调经历与行政岗高度相关。',
      ),
    ],
  ),

  // 16. 科研 / 读研申请
  RoleProfile(
    id: 'research',
    name: '科研/读研申请',
    aliases: ['科研', '读研', '研究生', '博士', '硕士', 'phd', '申请', '学术', '保研', '考研', '学者', '实验室'],
    requiredCerts: [],
    coreSkills: ['文献阅读', '实验设计', '数据分析', '学术写作', '英语', '统计/编程', '批判思维'],
    typicalExperiences: ['科研项目', '论文/专利', '学术竞赛', '实验室实习', '会议报告'],
    bonusItems: ['一作论文', '顶会/期刊', '竞赛获奖', '导师推荐', '英语成绩'],
    actions: [
      RoleAction(
        action: '明确研究方向并联系意向导师',
        category: 'other',
        expectedGain: 25,
        effort: 'medium',
        timeEstimate: '1–2 个月',
        rationale: '方向匹配与导师意向是录取的决定性因素。',
        resources: ['https://www.nature.com'],
      ),
      RoleAction(
        action: '参与科研项目/进入实验室',
        category: 'experience',
        expectedGain: 25,
        effort: 'high',
        timeEstimate: '3–12 个月',
        rationale: '真实科研经历是申请的核心材料与推荐信来源。',
      ),
      RoleAction(
        action: '撰写并投稿论文/专利',
        category: 'portfolio',
        expectedGain: 20,
        effort: 'high',
        timeEstimate: '6–12 个月',
        rationale: '一作论文显著提升学术竞争力。',
      ),
      RoleAction(
        action: '备考雅思/托福/GRE',
        category: 'skill',
        expectedGain: 15,
        effort: 'high',
        timeEstimate: '3–6 个月',
        rationale: '英语成绩是海外申请（及部分保研）的硬门槛。',
        resources: ['https://www.ets.org', 'https://ielts.org'],
      ),
      RoleAction(
        action: '提升文献阅读与学术写作',
        category: 'skill',
        expectedGain: 10,
        effort: 'low',
        timeEstimate: '持续',
        rationale: '文献与写作是科研日常，也是面试常考点。',
        resources: ['https://scholar.google.com'],
      ),
      RoleAction(
        action: '参加学术会议与学科竞赛',
        category: 'experience',
        expectedGain: 10,
        effort: 'medium',
        timeEstimate: '1–6 个月',
        rationale: '会议与竞赛扩展视野并丰富简历。',
      ),
    ],
  ),
];
