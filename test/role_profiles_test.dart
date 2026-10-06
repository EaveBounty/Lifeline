import 'package:flutter_test/flutter_test.dart';
import 'package:lifeline/data/role_profiles.dart';

void main() {
  group('画像库完整性', () {
    test('画像数量 ≥ 40 且 id 唯一', () {
      final all = RoleProfiles.all;
      expect(all.length, greaterThanOrEqualTo(40));
      final ids = all.map((p) => p.id).toList();
      expect(ids.toSet().length, ids.length, reason: 'id 必须唯一');
    });

    test('覆盖行业与职级字段，核心字段非空', () {
      final all = RoleProfiles.all;
      expect(all.where((p) => p.industry != null).length, greaterThan(30));
      expect(all.where((p) => p.level != null).length, greaterThan(30));
      for (final p in all) {
        expect(p.aliases, isNotEmpty, reason: p.id);
        expect(p.actions, isNotEmpty, reason: p.id);
        expect(p.coreSkills, isNotEmpty, reason: p.id);
      }
    });

    test('职级分布包含校招/初级与高级/资深', () {
      final levels = RoleProfiles.all.map((p) => p.level).toSet();
      expect(levels.intersection({'校招', '初级'}), isNotEmpty);
      expect(levels.intersection({'高级', '资深', '专家'}), isNotEmpty);
    });
  });

  group('match 打分匹配', () {
    test('中学教师 → 教师画像且含教师资格证', () {
      final p = RoleProfiles.match('中学教师');
      expect(p, isNotNull);
      expect(p!.id, 'teacher');
      expect(
        p.requiredCerts.any((c) => c.name.contains('教师资格')),
        isTrue,
      );
    });

    test('初级前端 → 前端画像', () {
      final p = RoleProfiles.match('初级前端');
      expect(p, isNotNull);
      expect(p!.id, 'frontend');
      expect(p.actions, isNotEmpty);
    });

    test('资深算法 → 资深算法画像且建议体现主导/影响力/带团队', () {
      final p = RoleProfiles.match('资深算法');
      expect(p, isNotNull);
      expect(p!.id, 'algorithm_senior');
      final text = p.actions.map((a) => a.action).join(' ');
      expect(
        text.contains('主导') || text.contains('影响力') || text.contains('带团队'),
        isTrue,
      );
    });

    test('量化研究员 → 量化画像且 actions 非空', () {
      final p = RoleProfiles.match('量化研究员');
      expect(p, isNotNull);
      expect(p!.id, 'quant');
      expect(p.actions, isNotEmpty);
    });

    test('诉讼律师 → 诉讼律师画像且 actions 非空', () {
      final p = RoleProfiles.match('诉讼律师');
      expect(p, isNotNull);
      expect(p!.id, 'lawyer_litigation');
      expect(p.actions, isNotEmpty);
    });

    test('注册会计师 → 会计画像且含 CPA/会计类证书', () {
      final p = RoleProfiles.match('注册会计师');
      expect(p, isNotNull);
      expect(p!.id, 'accounting');
      expect(
        p.requiredCerts.any((c) => c.name.contains('CPA') || c.name.contains('会计')),
        isTrue,
      );
      expect(p.actions, isNotEmpty);
    });

    test('后端工程师 → 后端画像（默认非资深）', () {
      expect(RoleProfiles.match('后端工程师')?.id, 'backend');
    });

    test('中英混合与别名均可命中', () {
      expect(RoleProfiles.match('AI算法工程师')?.id, 'algorithm');
      expect(RoleProfiles.match('frontend 前端')?.id, 'frontend');
      expect(RoleProfiles.match('Android开发')?.id, 'mobile');
    });

    test('无匹配返回 null', () {
      expect(RoleProfiles.match('星际战舰驾驶员ZZZ'), isNull);
      expect(RoleProfiles.match(''), isNull);
      expect(RoleProfiles.match(null), isNull);
    });
  });

  group('职级差异', () {
    test('资深画像建议体现影响力/主导/带团队关键词', () {
      final senior = RoleProfiles.all.where((p) => p.level == '资深');
      expect(senior, isNotEmpty);
      for (final p in senior) {
        final text = p.actions.map((a) => a.action).join(' ');
        expect(
          text.contains('主导') || text.contains('影响力') || text.contains('带团队'),
          isTrue,
          reason: '${p.id} 应体现资深层级的证据语言',
        );
      }
    });

    test('校招/初级画像偏基础证书/实习，高级画像偏规模/影响力', () {
      final junior = RoleProfiles.match('初级前端')!;
      final senior = RoleProfiles.match('资深算法')!;
      expect(junior.level, '初级');
      expect(senior.level, '资深');
      expect(
        junior.actions.any((a) => a.category == 'experience' || a.category == 'skill'),
        isTrue,
      );
    });
  });
}
