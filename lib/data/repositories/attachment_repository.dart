/// 附件仓库：外部文件复制进 `attachments/<yyyy>/<sha1前8>-<原名>`，并写索引。
library;

import 'dart:io';

import 'package:path/path.dart' as p;
import 'package:uuid/uuid.dart';

import '../../core/constants.dart';
import '../../core/logging.dart';
import '../../core/utils/file_utils.dart';
import '../../core/utils/path_guard.dart';
import '../db/database.dart';
import '../models/attachment.dart';

/// 记录/profile 中声明的附件相对路径（真相源），用于索引重建。
class DeclaredAttachment {
  const DeclaredAttachment(this.relPath, {this.recordId});

  final String relPath;
  final String? recordId;
}

class AttachmentRepository {
  AttachmentRepository({required this.rootPath, required this.db});

  final String rootPath;
  final LifelineDatabase db;

  static const Uuid _uuid = Uuid();

  Future<Attachment> importFile(
    File source, {
    String? recordId,
    String? caption,
    String? rootPath,
  }) async {
    final root = rootPath ?? this.rootPath;
    final bytes = await source.readAsBytes();
    final hash = sha1OfBytes(bytes);
    final ext = p.extension(source.path);
    final baseName = p.basename(source.path);
    final year = DateTime.now().year.toString();
    final rel = p.join(
      SyncLayout.attachmentsDir,
      year,
      '${hash.substring(0, 8)}-$baseName',
    );
    final target = File(p.join(root, rel));
    if (!await target.exists()) {
      await writeBytesAtomic(target.path, bytes);
    }

    final attachment = Attachment(
      id: _uuid.v4(),
      recordId: recordId,
      relPath: rel.replaceAll(r'\', '/'),
      filename: baseName,
      mime: _mimeFor(ext),
      size: bytes.length,
      sha1: hash,
      caption: caption,
      createdAt: DateTime.now(),
    );
    await db.upsertAttachment(attachment);
    return attachment;
  }

  Future<void> delete(String id) async {
    final all = await db.allAttachments();
    Attachment? found;
    for (final a in all) {
      if (a.id == id) {
        found = a;
        break;
      }
    }
    if (found != null) {
      final abs = resolveWithinRoot(rootPath, found.relPath);
      if (abs != null) {
        final file = File(abs);
        if (await file.exists()) await file.delete();
      } else {
        appLog.warning('拒绝删除越界附件路径: ${found.relPath}');
      }
    }
    await db.deleteAttachment(id);
  }

  /// 相对根路径拼接为绝对文件；越界抛 [ArgumentError]。
  File resolve(Attachment attachment) {
    final abs = resolveWithinRoot(rootPath, attachment.relPath);
    if (abs == null) {
      throw ArgumentError.value(attachment.relPath, 'relPath', '附件路径越界');
    }
    return File(abs);
  }

  /// 索引重建：从声明的相对路径扫描文件本身，重建附件索引。
  ///
  /// 文件缺失或路径越界者跳过；已存在的附件 id/caption/createdAt 尽量保留。
  Future<List<Attachment>> rebuildFromDeclarations(
    List<DeclaredAttachment> declared,
  ) async {
    final existing = await db.allAttachments();
    final byRel = {for (final a in existing) a.relPath: a};
    final out = <Attachment>[];
    final seen = <String>{};
    for (final d in declared) {
      final rel = d.relPath.trim().replaceAll(r'\', '/');
      if (rel.isEmpty || !seen.add(rel)) continue;
      final abs = resolveWithinRoot(rootPath, rel);
      if (abs == null) {
        appLog.warning('跳过越界附件路径: $rel');
        continue;
      }
      final file = File(abs);
      if (!await file.exists()) continue;
      final bytes = await file.readAsBytes();
      final prior = byRel[rel];
      out.add(Attachment(
        id: prior?.id ?? _uuid.v4(),
        recordId: d.recordId ?? prior?.recordId,
        relPath: rel,
        filename: p.basename(rel),
        mime: _mimeFor(p.extension(rel)),
        size: bytes.length,
        sha1: sha1OfBytes(bytes),
        caption: prior?.caption,
        createdAt: prior?.createdAt ?? DateTime.now(),
      ));
    }
    return out;
  }

  Future<List<Attachment>> forRecord(String id) async {
    final all = await db.allAttachments();
    return all.where((a) => a.recordId == id).toList();
  }

  static String? _mimeFor(String extensionWithDot) {
    const map = {
      '.jpg': 'image/jpeg',
      '.jpeg': 'image/jpeg',
      '.png': 'image/png',
      '.gif': 'image/gif',
      '.webp': 'image/webp',
      '.bmp': 'image/bmp',
      '.heic': 'image/heic',
      '.pdf': 'application/pdf',
      '.doc': 'application/msword',
      '.docx':
          'application/vnd.openxmlformats-officedocument.wordprocessingml.document',
      '.xls': 'application/vnd.ms-excel',
      '.xlsx':
          'application/vnd.openxmlformats-officedocument.spreadsheetml.sheet',
      '.ppt': 'application/vnd.ms-powerpoint',
      '.pptx':
          'application/vnd.openxmlformats-officedocument.presentationml.presentation',
      '.txt': 'text/plain',
      '.md': 'text/markdown',
    };
    return map[extensionWithDot.toLowerCase()];
  }
}
