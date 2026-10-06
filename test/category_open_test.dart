import 'package:flutter_test/flutter_test.dart';
import 'package:lifeline/data/models/app_settings.dart';
import 'package:lifeline/data/models/profile.dart';
import 'package:lifeline/data/models/profile_record.dart';
import 'package:lifeline/data/models/record_category.dart';
import 'package:lifeline/services/compile/resume_compiler.dart';

ProfileRecord _rec(String slug, String title, {String status = 'active', int order = 0}) =>
    ProfileRecord(
      id: 'rec-$slug-$title',
      categorySlug: slug,
      title: title,
      status: status,
      order: order,
      createdAt: DateTime.now(),
      updatedAt: DateTime.now(),
    );

void main() {
  group('slug 生成与规整', () {
    test('slugify 由名称生成安全 slug', () {
      expect(slugify('志愿服务'), isNotEmpty);
      expect(slugify('Open Source 贡献'), 'open-source-贡献');
      expect(slugify('  A/B\\C  '), 'a-b-c');
      expect(slugify(''), 'category');
    });

    test('sanitizeSlug 去除路径分隔与越界片段', () {
      expect(sanitizeSlug('a/b'), 'a-b');
      expect(sanitizeSlug('../etc'), 'etc');
      expect(sanitizeSlug('...'), 'category');
      expect(sanitizeSlug('ok_slug-1'), 'ok_slug-1');
    });
  });

  group('CategoryDef 解析', () {
    test('JSON 往返保留字段', () {
      const def = CategoryDef(slug: 'volunteer', label: '志愿服务', icon: 'groups', order: 3);
      final back = CategoryDef.fromJson(def.toJson());
      expect(back.slug, 'volunteer');
      expect(back.label, '志愿服务');
      expect(back.icon, 'groups');
      expect(back.order, 3);
    });

    test('缺失 slug 时由 label 生成', () {
      final def = CategoryDef.fromJson({'label': '开源贡献'});
      expect(def.slug, isNotEmpty);
      expect(def.label, '开源贡献');
    });

    test('resolveCategory 未登记 slug 回退（标签即 slug）', () {
      final def = resolveCategory(kDefaultCategories, 'ghost');
      expect(def.slug, 'ghost');
      expect(def.label, 'ghost');
      expect(def.icon, 'category');
    });
  });

  group('AppSettings 分类持久化', () {
    test('无 categories 字段时回退默认集', () {
      final s = AppSettings.fromJson({'schema_version': 1});
      expect(s.categories.length, kDefaultCategories.length);
      expect(s.categories.map((c) => c.slug), contains('education'));
    });

    test('自定义 categories 可往返', () {
      const cats = [
        CategoryDef(slug: 'work', label: '工作', icon: 'work', order: 0),
        CategoryDef(slug: 'life', label: '生活', icon: 'home', order: 1),
      ];
      final s = AppSettings.initial().copyWith(categories: cats);
      final back = AppSettings.fromJson(s.toJson());
      expect(back.categories.map((c) => c.slug).toList(), ['work', 'life']);
      expect(back.categories.first.label, '工作');
    });
  });

  group('编译器支持自定义 / 孤儿分类', () {
    test('按注册分类顺序输出，孤儿分类追加在后', () {
      const cats = [
        CategoryDef(slug: 'volunteer', label: '志愿服务', order: 0),
        CategoryDef(slug: 'opensource', label: '开源贡献', order: 1),
      ];
      final records = [
        _rec('opensource', 'PR 合并'),
        _rec('volunteer', '社区服务'),
        _rec('ghost', '未登记分类'),
        _rec('volunteer', '已归档', status: 'archived'),
      ];
      final doc = const ResumeCompiler()
          .compile(profile: Profile.empty(), records: records, categories: cats);

      expect(doc.sections.length, 3);
      expect(doc.sections[0].key, 'volunteer');
      expect(doc.sections[0].title, '志愿服务');
      expect(doc.sections[1].key, 'opensource');
      expect(doc.sections[2].key, 'ghost');
      expect(doc.sections[2].title, 'ghost');
      // 归档记录被过滤。
      expect(doc.sections[0].items.length, 1);
    });
  });
}
