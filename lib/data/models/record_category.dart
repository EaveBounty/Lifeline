/// 信息分类：**开放、可编辑**的分类定义（用户可增 / 改 / 删 / 排序）。
///
/// 不再使用固定枚举；分类以 `CategoryDef` 列表存于 `lifeline.yaml` 的
/// `categories:` 下（见 [AppSettings]），磁盘目录与记录 JSON 的 `category`
/// 字段统一使用稳定的 [CategoryDef.slug]。删除分类不会删除记录：记录保留
/// 原 slug，UI 以 [resolveCategory] 回退显示。内置默认集见 [kDefaultCategories]。
library;

/// 分类定义。
class CategoryDef {
  /// 稳定标识：磁盘目录名与记录 JSON `category` 值。建议小写字母/数字/`-`/`_`。
  final String slug;

  /// 显示名（可编辑）。
  final String label;

  /// 图标键（映射见 UI 层 `categoryIcon`）。
  final String icon;

  /// 排序权重（越小越靠前）。
  final int order;

  const CategoryDef({
    required this.slug,
    required this.label,
    this.icon = 'category',
    this.order = 0,
  });

  CategoryDef copyWith({String? slug, String? label, String? icon, int? order}) =>
      CategoryDef(
        slug: slug ?? this.slug,
        label: label ?? this.label,
        icon: icon ?? this.icon,
        order: order ?? this.order,
      );

  Map<String, dynamic> toJson() => {
        'slug': slug,
        'label': label,
        'icon': icon,
        'order': order,
      };

  factory CategoryDef.fromJson(Map<String, dynamic> j) {
    final rawSlug = '${j['slug'] ?? ''}'.trim();
    final slug = sanitizeSlug(rawSlug.isEmpty ? slugify('${j['label'] ?? ''}') : rawSlug);
    return CategoryDef(
      slug: slug,
      label: '${j['label'] ?? slug}'.trim().isEmpty ? slug : '${j['label']}'.trim(),
      icon: (j['icon'] ?? 'category') as String,
      order: (j['order'] as num?)?.toInt() ?? 0,
    );
  }
}

/// 未知分类回退时使用的内置 slug。
const String kFallbackCategorySlug = 'custom';

/// 内置默认分类集（与历史版本一致，可被用户编辑）。
const List<CategoryDef> kDefaultCategories = [
  CategoryDef(slug: 'education', label: '教育经历', icon: 'school', order: 0),
  CategoryDef(slug: 'experience', label: '工作/实习经历', icon: 'work', order: 1),
  CategoryDef(slug: 'projects', label: '项目经历', icon: 'account_tree', order: 2),
  CategoryDef(slug: 'research', label: '科研经历', icon: 'science', order: 3),
  CategoryDef(slug: 'awards', label: '荣誉奖项', icon: 'emoji_events', order: 4),
  CategoryDef(
      slug: 'publications', label: '论文/专利/著作', icon: 'menu_book', order: 5),
  CategoryDef(
      slug: 'certificates', label: '证书资质', icon: 'verified', order: 6),
  CategoryDef(slug: 'skills', label: '技能特长', icon: 'construction', order: 7),
  CategoryDef(slug: 'languages', label: '语言能力', icon: 'translate', order: 8),
  CategoryDef(
      slug: 'activities', label: '社团/志愿/社会实践', icon: 'groups', order: 9),
  CategoryDef(
      slug: 'trainings', label: '培训进修', icon: 'model_training', order: 10),
  CategoryDef(slug: 'works', label: '作品/成果', icon: 'palette', order: 11),
  CategoryDef(
      slug: 'interests', label: '兴趣爱好', icon: 'sports_esports', order: 12),
  CategoryDef(
      slug: 'references', label: '推荐人', icon: 'contact_phone', order: 13),
  CategoryDef(slug: 'custom', label: '自定义', icon: 'category', order: 14),
];

/// 生成安全 slug：小写、非字母数字转为 `-`、去除首尾与连续 `-`。
String slugify(String input) {
  final s = input
      .trim()
      .toLowerCase()
      .replaceAll(RegExp(r'[^a-z0-9\u4e00-\u9fa5]+'), '-')
      .replaceAll(RegExp(r'^-+|-+$'), '')
      .replaceAll(RegExp(r'-{2,}'), '-');
  return s.isEmpty ? 'category' : s;
}

/// 将任意 slug 规整为可安全用作目录名的形式（禁止路径分隔与 `..`）。
String sanitizeSlug(String input) {
  final s = input
      .trim()
      .replaceAll(RegExp(r'[\\/\s]+'), '-')
      .replaceAll(RegExp(r'[^A-Za-z0-9_\-.]'), '')
      .replaceAll(RegExp(r'^\.+'), '')
      .replaceAll(RegExp(r'-{2,}'), '-')
      .replaceAll(RegExp(r'^-+|-+$'), '');
  return s.isEmpty ? 'category' : s;
}

/// 按 slug 解析分类；未知 slug 返回回退定义（标签即 slug，可正常显示旧数据）。
CategoryDef resolveCategory(List<CategoryDef> categories, String? slug) {
  final key = (slug == null || slug.trim().isEmpty)
      ? kFallbackCategorySlug
      : slug.trim();
  for (final c in categories) {
    if (c.slug == key) return c;
  }
  return CategoryDef(slug: key, label: key, icon: 'category');
}

/// 复制并按 [CategoryDef.order] 升序排列（并列按 label）。
List<CategoryDef> sortedCategories(Iterable<CategoryDef> categories) {
  final list = categories.toList()
    ..sort((a, b) {
      final c = a.order.compareTo(b.order);
      return c != 0 ? c : a.label.compareTo(b.label);
    });
  return list;
}
