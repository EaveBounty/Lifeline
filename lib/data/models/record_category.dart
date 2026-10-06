/// 信息分类枚举：驱动记录目录、UI、简历章节、AI 归类的统一枚举。
library;

enum RecordCategory {
  education('education', '教育经历', 'school', 'education'),
  experience('experience', '工作/实习经历', 'work', 'experience'),
  projects('projects', '项目经历', 'projects', 'projects'),
  research('research', '科研经历', 'science', 'research'),
  awards('awards', '荣誉奖项', 'emoji_events', 'awards'),
  publications('publications', '论文/专利/著作', 'menu_book', 'publications'),
  certificates('certificates', '证书资质', 'verified', 'certificates'),
  skills('skills', '技能特长', 'construction', 'skills'),
  languages('languages', '语言能力', 'translate', 'languages'),
  activities('activities', '社团/志愿/社会实践', 'groups', 'activities'),
  trainings('trainings', '培训进修', 'model_training', 'trainings'),
  works('works', '作品/成果', 'palette', 'works'),
  interests('interests', '兴趣爱好', 'sports_esports', 'interests'),
  references('references', '推荐人', 'contact_phone', 'references'),
  custom('custom', '自定义', 'category', 'custom');

  const RecordCategory(this.slug, this.labelZh, this.iconName, this.sectionKey);

  /// 磁盘目录名 / JSON category 值。
  final String slug;

  /// 中文显示名。
  final String labelZh;

  /// Material 图标名（UI 层映射为 IconData，模型层不依赖 Flutter）。
  final String iconName;

  /// 简历 IR 章节键。
  final String sectionKey;

  static RecordCategory? fromSlug(String? slug) {
    if (slug == null) return null;
    for (final c in values) {
      if (c.slug == slug) return c;
    }
    return null;
  }

  /// 默认排序权重（简历中章节的常规顺序，越小越靠前）。
  int get defaultOrder => index;
}
