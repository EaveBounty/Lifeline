import 'dart:convert';
import 'dart:ffi';
import 'dart:io';

import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lifeline/core/utils/path_guard.dart';
import 'package:lifeline/data/db/database.dart';
import 'package:lifeline/data/models/ai_provider.dart';
import 'package:lifeline/data/models/profile.dart';
import 'package:lifeline/data/models/profile_record.dart';
import 'package:lifeline/data/repositories/attachment_repository.dart';
import 'package:lifeline/data/repositories/records_repository.dart';
import 'package:lifeline/data/repositories/resume_repository.dart';
import 'package:lifeline/features/attachments/attachment_preview.dart';
import 'package:lifeline/services/compile/resume_compiler.dart';
import 'package:path/path.dart' as p;
// 测试注入：宿主机仅有 libsqlite3.so.0（无 dev 符号链接）。
// ignore: depend_on_referenced_packages
import 'package:sqlite3/open.dart';

Future<void> _writeFile(String root, String rel, List<int> bytes) async {
  final file = File(p.join(root, rel));
  await file.parent.create(recursive: true);
  await file.writeAsBytes(bytes);
}

Future<void> _writeJson(String root, String rel, Object data) async {
  final file = File(p.join(root, rel));
  await file.parent.create(recursive: true);
  await file.writeAsString(jsonEncode(data));
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUpAll(() {
    if (Platform.isLinux) {
      open.overrideFor(
        OperatingSystem.linux,
        () => DynamicLibrary.open('libsqlite3.so.0'),
      );
    }
  });

  Future<Directory> tempRoot() async {
    final dir = await Directory.systemTemp.createTemp('lifeline_reg');
    addTearDown(() => dir.delete(recursive: true));
    return dir;
  }

  Future<LifelineDatabase> memoryDb() async {
    final dir = await Directory.systemTemp.createTemp('lifeline_db');
    addTearDown(() => dir.delete(recursive: true));
    final db = LifelineDatabase(
      File(p.join(dir.path, 'index.sqlite')),
      executor: NativeDatabase.memory(),
    );
    addTearDown(db.close);
    return db;
  }

  group('A1 附件索引可 100% 重建', () {
    test('rebuildIndex 从记录 attachments 与 profile.photo_path 扫描重建', () async {
      final root = await tempRoot();
      final db = await memoryDb();
      const recRel = 'attachments/2026/rec-cert.pdf';
      const photoRel = 'attachments/2026/photo.jpg';
      await _writeFile(root.path, recRel, [1, 2, 3, 4]);
      await _writeFile(root.path, photoRel, [5, 6, 7]);

      const id = '11111111-1111-1111-1111-111111111111';
      final record = ProfileRecord(
        id: id,
        categorySlug: 'certificates',
        title: '证书',
        attachments: const [recRel],
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
      );
      await _writeJson(
          root.path, 'data/records/certificates/$id.json', record.toJson());
      await _writeJson(
        root.path,
        'data/profile.json',
        Profile(updatedAt: DateTime.now(), photoPath: photoRel).toJson(),
      );

      await RecordsRepository(rootPath: root.path, db: db).rebuildIndex();

      final atts = await db.allAttachments();
      expect(atts.length, 2);
      final byRel = {for (final a in atts) a.relPath: a};
      expect(byRel[recRel], isNotNull);
      expect(byRel[recRel]!.sha1.isNotEmpty, isTrue);
      expect(byRel[recRel]!.size, 4);
      expect(byRel[recRel]!.recordId, id);
      expect(byRel[photoRel], isNotNull);
      expect(byRel[photoRel]!.recordId, isNull);
      expect(byRel[photoRel]!.mime, 'image/jpeg');
    });
  });

  group('A2 AI 录入附件回写记录', () {
    test('导入返回 relPath 且回写后可重建保留', () async {
      final root = await tempRoot();
      final db = await memoryDb();
      const id = '22222222-2222-2222-2222-222222222222';
      final src = File(p.join(root.path, 'src.png'));
      await src.writeAsBytes([9, 9, 9, 9, 9]);

      final att = await AttachmentRepository(rootPath: root.path, db: db)
          .importFile(src, recordId: id, caption: 'AI 录入佐证图片');
      expect(att.relPath, startsWith('attachments/'));

      var record = ProfileRecord(
        id: id,
        categorySlug: 'custom',
        title: 'AI 条目',
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
      );
      record = record.copyWith(attachments: [att.relPath]);
      final repo = RecordsRepository(rootPath: root.path, db: db);
      await repo.save(record);
      await repo.rebuildIndex();

      final atts = await db.allAttachments();
      expect(atts.any((a) => a.relPath == att.relPath), isTrue);
      final records = await repo.loadAll();
      expect(records.single.attachments, [att.relPath]);
    });
  });

  group('A3 路径遍历防护', () {
    test('isSafeId / resolveWithinRoot 拒绝越界', () {
      expect(isSafeId('../../x'), isFalse);
      expect(isSafeId('..'), isFalse);
      expect(isSafeId('a/b'), isFalse);
      expect(isSafeId(r'a\b'), isFalse);
      expect(isSafeId(''), isFalse);
      expect(isSafeId('11111111-1111-1111-1111-111111111111'), isTrue);
      expect(resolveWithinRoot('/tmp/root', '../../etc/passwd'), isNull);
      expect(resolveWithinRoot('/tmp/root', '/etc/passwd'), isNull);
      expect(
        resolveWithinRoot('/tmp/root', 'attachments/a.png'),
        p.normalize('/tmp/root/attachments/a.png'),
      );
    });

    test('attachmentFileOf 越界抛 ArgumentError', () {
      expect(
        () => attachmentFileOf('/tmp/root', '../../etc/passwd'),
        throwsArgumentError,
      );
    });

    test('RecordsRepository 拒绝非法 id 写盘 / ResumeRepository 拒绝越界', () async {
      final root = await tempRoot();
      final db = await memoryDb();
      final bad = ProfileRecord(
        id: '../../evil',
        categorySlug: 'education',
        title: 'x',
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
      );
      final repo = RecordsRepository(rootPath: root.path, db: db);
      await expectLater(repo.save(bad), throwsArgumentError);

      await expectLater(
        ResumeRepository(root.path).delete('../../x'),
        throwsArgumentError,
      );
    });
  });

  group('B8 importAll 非法 id', () {
    test('跳过非法 id，合法记录正常落库且无越界文件', () async {
      final root = await tempRoot();
      final db = await memoryDb();
      const goodId = '33333333-3333-3333-3333-333333333333';
      final good = ProfileRecord(
        id: goodId,
        categorySlug: 'education',
        title: '好记录',
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
      );
      final bad = ProfileRecord(
        id: '../../evil',
        categorySlug: 'education',
        title: '坏记录',
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
      );
      final repo = RecordsRepository(rootPath: root.path, db: db);
      await repo.importAll([good, bad]);

      expect(await db.recordCount(), 1);
      expect(
        File(p.join(root.path, 'data/records/education/$goodId.json'))
            .existsSync(),
        isTrue,
      );
      expect(File(p.join(root.path, 'data/evil.json')).existsSync(), isFalse);
      expect(File(p.join(root.path, 'evil.json')).existsSync(), isFalse);
    });
  });

  group('B2 编译器语言接线', () {
    test('language=en 输出英文章节名', () {
      final record = ProfileRecord(
        id: 'x',
        categorySlug: 'experience',
        title: 'Engineer',
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
      );
      final en = const ResumeCompiler()
          .compile(profile: Profile.empty(), records: [record], language: 'en');
      final zh = const ResumeCompiler()
          .compile(profile: Profile.empty(), records: [record], language: 'zh');
      expect(en.sections.single.title, 'experience');
      expect(zh.sections.single.title, '工作/实习经历');
    });
  });

  group('B7 Provider 额外请求头脱敏', () {
    test('保存前剥离 Authorization / 密钥类头部', () {
      const provider = AiProvider(
        id: 'p',
        name: 'P',
        baseUrl: 'https://x',
        model: 'm',
        keyRef: 'p',
        extraHeaders: {
          'Authorization': 'Bearer secret',
          'X-Api-Key': 'k',
          'X-Trace-Id': 't',
        },
      );
      final clean = provider.sanitized();
      expect(clean.extraHeaders, {'X-Trace-Id': 't'});
    });
  });
}
