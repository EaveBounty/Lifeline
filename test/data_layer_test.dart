import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:lifeline/data/config/app_config.dart';
import 'package:lifeline/data/models/ai_provider.dart';
import 'package:lifeline/data/models/app_settings.dart';
import 'package:lifeline/data/models/profile.dart';
import 'package:lifeline/data/models/profile_record.dart';
import 'package:lifeline/data/models/record_category.dart';
import 'package:lifeline/data/repositories/root_manager.dart';
import 'package:lifeline/data/repositories/settings_repository.dart';
import 'package:lifeline/services/compile/resume_compiler.dart';
import 'package:path/path.dart' as p;
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('ProfileRecord JSON 往返', () {
    test('字段与列表完整保留', () {
      final now = DateTime.parse('2026-01-02T03:04:05.000');
      final record = ProfileRecord(
        id: 'r1',
        category: RecordCategory.education,
        title: '某大学',
        organization: '某大学',
        role: '学生',
        location: '长沙',
        startDate: '2020-09',
        endDate: '2024-06',
        description: 'desc',
        highlights: ['a', 'b'],
        tags: ['t'],
        fields: {'major': 'CS'},
        attachments: ['attachments/2026/x.pdf'],
        links: [const RecordLink(label: 'site', url: 'https://x')],
        createdAt: now,
        updatedAt: now,
        order: 3,
      );

      final decoded = ProfileRecord.fromJson(record.toJson());
      expect(decoded.id, record.id);
      expect(decoded.category, RecordCategory.education);
      expect(decoded.title, record.title);
      expect(decoded.organization, record.organization);
      expect(decoded.startDate, '2020-09');
      expect(decoded.highlights, ['a', 'b']);
      expect(decoded.fields['major'], 'CS');
      expect(decoded.attachments.single, 'attachments/2026/x.pdf');
      expect(decoded.links.single.url, 'https://x');
      expect(decoded.createdAt, now);
      expect(decoded.order, 3);
    });
  });

  group('AppSettings YAML 往返', () {
    test('保存后可完整读回', () async {
      final dir = await Directory.systemTemp.createTemp('lifeline_settings');
      addTearDown(() => dir.delete(recursive: true));

      final repo = SettingsRepository(dir.path);
      final settings = AppSettings.initial().copyWith(
        language: 'en',
        providers: [AiPresets.presets.first],
        defaultAiProviderId: 'openai',
      );
      await repo.save(settings);

      expect(File(p.join(dir.path, 'lifeline.yaml')).existsSync(), isTrue);
      final loaded = await repo.load();
      expect(loaded.language, 'en');
      expect(loaded.providers.length, 1);
      expect(loaded.providers.first.id, 'openai');
      expect(loaded.defaultAiProviderId, 'openai');
    });
  });

  group('RootManager.initialize 结构', () {
    test('创建目录与默认文件，且不破坏已有内容', () async {
      SharedPreferences.setMockInitialValues({});
      final config = await AppConfig.load();
      final dir = await Directory.systemTemp.createTemp('lifeline_root');
      addTearDown(() => dir.delete(recursive: true));

      final rm = RootManager(config);
      expect(await rm.probe(dir.path), RootProbe.empty);

      final result = await rm.initialize(dir.path);
      expect(result.isOk, isTrue);
      expect(rm.isInitialized, isTrue);
      expect(await rm.probe(dir.path), RootProbe.initialized);

      expect(File(p.join(dir.path, 'lifeline.yaml')).existsSync(), isTrue);
      expect(
        File(p.join(dir.path, 'data', 'profile.json')).existsSync(),
        isTrue,
      );
      expect(
        File(p.join(dir.path, '.lifeline', 'state.json')).existsSync(),
        isTrue,
      );
      expect(Directory(p.join(dir.path, 'attachments')).existsSync(), isTrue);
      expect(
        Directory(p.join(dir.path, 'data', 'resumes')).existsSync(),
        isTrue,
      );
      for (final c in RecordCategory.values) {
        expect(
          Directory(p.join(dir.path, 'data', 'records', c.slug)).existsSync(),
          isTrue,
          reason: c.slug,
        );
      }

      final profileFile = File(p.join(dir.path, 'data', 'profile.json'));
      final before = await profileFile.readAsString();
      await rm.initialize(dir.path);
      expect(await profileFile.readAsString(), before);
    });
  });

  group('ResumeCompiler 基本编译', () {
    test('header/summary/分组与状态过滤', () {
      final profile = Profile(
        updatedAt: DateTime.now(),
        sections: {
          ProfileSections.identity: {
            'name': const ProfileField(key: 'name', value: '张三'),
            'english_name':
                const ProfileField(key: 'english_name', value: 'Zhang San'),
          },
          ProfileSections.contact: {
            'email': const ProfileField(key: 'email', value: 'a@b.com'),
          },
          ProfileSections.summary: {
            'summary': const ProfileField(key: 'summary', value: '个人简介'),
          },
        },
      );
      final records = [
        ProfileRecord(
          id: 'x',
          category: RecordCategory.experience,
          title: '工程师',
          organization: 'ACME',
          role: '后端',
          startDate: '2024-01',
          createdAt: DateTime.now(),
          updatedAt: DateTime.now(),
          highlights: ['完成了核心模块'],
        ),
        ProfileRecord(
          id: 'y',
          category: RecordCategory.experience,
          title: '归档项',
          createdAt: DateTime.now(),
          updatedAt: DateTime.now(),
          status: 'archived',
        ),
      ];

      final doc = const ResumeCompiler()
          .compile(profile: profile, records: records);
      expect(doc.header.name, '张三');
      expect(doc.header.englishName, 'Zhang San');
      expect(doc.header.contacts.any((c) => c.value == 'a@b.com'), isTrue);
      expect(doc.summary, '个人简介');
      expect(doc.sections.length, 1);
      expect(doc.sections.single.items.length, 1);
      expect(doc.sections.single.items.single.meta, contains('ACME'));
      expect(doc.sections.single.items.single.bullets, ['完成了核心模块']);

      final empty = const ResumeCompiler()
          .compile(profile: Profile.empty(), records: const []);
      expect(empty.sections, isEmpty);
      expect(empty.header.name, '');
    });
  });
}
