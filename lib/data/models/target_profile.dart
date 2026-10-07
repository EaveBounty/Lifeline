/// 求职目标画像维度：目标级别 / 职业阶段 / 赛道。
///
/// 三项用于「级别校准 + 赛道加权」。所有对外展示均提供 [plain]（大白话解释），
/// 供 UI 用可点击的说明气泡，避免专业名词造成困惑。
library;

class TargetLevel {
  final String id;
  final String label;
  final String plain;
  const TargetLevel._(this.id, this.label, this.plain);

  static const campus = TargetLevel._('campus', '应届/校招', '刚毕业或在校，靠学历、项目和潜力取胜');
  static const junior = TargetLevel._('junior', '初级（约 0–3 年）', '能独立完成明确任务，看执行力');
  static const mid = TargetLevel._('mid', '中级（约 3–5 年）', '能独立负责一个模块/方向，看结果');
  static const senior = TargetLevel._('senior', '高级（约 5–8 年）', '能主导系统/项目，看影响范围（scope）');
  static const lead = TargetLevel._('lead', '资深/骨干（8 年以上）', '能影响多个团队/业务线，能定方向');
  static const manager = TargetLevel._('manager', '管理岗', '带团队、定目标、对业务结果负责');

  static const List<TargetLevel> all = [campus, junior, mid, senior, lead, manager];
  static TargetLevel byId(String? id) =>
      all.firstWhere((e) => e.id == id, orElse: () => mid);
}

class CareerStage {
  final String id;
  final String label;
  final String plain;
  const CareerStage._(this.id, this.label, this.plain);

  static const student = CareerStage._('student', '在校/应届', '还没正式工作，以教育和项目为主');
  static const early = CareerStage._('early', '职场初期', '工作几年，重点在成长与成果');
  static const mid = CareerStage._('mid', '职业中期', '有稳定成果，重点在专业深度与影响');
  static const senior = CareerStage._('senior', '资深', '看领导力与业务结果');
  static const manager = CareerStage._('manager', '管理', '看团队、战略与业绩');
  static const switcher = CareerStage._('switcher', '转行', '换赛道，重点在可迁移能力');

  static const List<CareerStage> all = [student, early, mid, senior, manager, switcher];
  static CareerStage byId(String? id) =>
      all.firstWhere((e) => e.id == id, orElse: () => early);
}

class Track {
  final String id;
  final String label;
  final String plain;
  const Track._(this.id, this.label, this.plain);

  static const general = Track._('general', '通用', '不确定就选这个，按岗位名自动判断');
  static const tech = Track._('tech', '互联网/技术', '看重项目、技术深度、量化结果（QPS、性能、规模）');
  static const finance = Track._('finance', '金融', '看重名校/学历、数字精确、实习连续性、建模');
  static const consulting = Track._('consulting', '咨询', '看重名校、案例、结构表达、领导力');
  static const academic = Track._('academic', '学术/科研', '看重论文/会议/项目，篇幅可长（CV 风格）');
  static const soe = Track._('soe', '央国企/体制', '看重学历、稳定性、政治面貌，多为官方报名表');
  static const design = Track._('design', '设计', '看重作品集与审美，简历只是索引');
  static const ops = Track._('ops', '运营/市场', '看重增长数字（GMV/DAU/ROI/转化）');

  static const List<Track> all = [
    general, tech, finance, consulting, academic, soe, design, ops,
  ];
  static Track byId(String? id) =>
      all.firstWhere((e) => e.id == id, orElse: () => general);

  /// 赛道对 10 个评估维度（见 evaluation）的权重；缺省为通用。
  Map<String, double> get dimensionWeights => switch (id) {
        'tech' => const {
            'relevance': .16, 'level': .13, 'impact': .15, 'ownership': .12,
            'depth': .16, 'differentiation': .07, 'structure': .05,
            'ats': .05, 'credibility': .08, 'language': .03,
          },
        'finance' => const {
            'relevance': .16, 'level': .12, 'impact': .12, 'ownership': .10,
            'depth': .16, 'differentiation': .08, 'structure': .05,
            'ats': .05, 'credibility': .13, 'language': .03,
          },
        'consulting' => const {
            'relevance': .15, 'level': .14, 'impact': .14, 'ownership': .10,
            'depth': .10, 'differentiation': .08, 'structure': .10,
            'ats': .04, 'credibility': .12, 'language': .03,
          },
        'academic' => const {
            'relevance': .14, 'level': .10, 'impact': .10, 'ownership': .08,
            'depth': .18, 'differentiation': .12, 'structure': .08,
            'ats': .03, 'credibility': .13, 'language': .04,
          },
        'soe' => const {
            'relevance': .15, 'level': .14, 'impact': .10, 'ownership': .08,
            'depth': .10, 'differentiation': .06, 'structure': .08,
            'ats': .07, 'credibility': .16, 'language': .06,
          },
        'design' => const {
            'relevance': .13, 'level': .10, 'impact': .10, 'ownership': .10,
            'depth': .14, 'differentiation': .16, 'structure': .08,
            'ats': .03, 'credibility': .10, 'language': .06,
          },
        'ops' => const {
            'relevance': .16, 'level': .11, 'impact': .18, 'ownership': .11,
            'depth': .07, 'differentiation': .09, 'structure': .09,
            'ats': .05, 'credibility': .11, 'language': .03,
          },
        _ => const {
            'relevance': .18, 'level': .12, 'impact': .16, 'ownership': .10,
            'depth': .12, 'differentiation': .08, 'structure': .07,
            'ats': .06, 'credibility': .08, 'language': .03,
          },
      };
}
