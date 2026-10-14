/// 照片库仓库：文件存 `attachments/<yyyy>/`，索引存 `data/photos.json`。
library;

import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:path/path.dart' as p;
import 'package:uuid/uuid.dart';

import '../../core/constants.dart';
import '../../core/logging.dart';
import '../../core/platform/io_platform.dart';
import '../../core/utils/file_utils.dart';
import '../../core/utils/path_guard.dart';
import '../json_store/json_file_store.dart';
import '../models/photo.dart';

class PhotoRepository {
  PhotoRepository(this.rootPath);

  final String rootPath;
  final JsonFileStore _store = JsonFileStore();
  static const Uuid _uuid = Uuid();

  File get _file =>
      File(p.join(rootPath, SyncLayout.dataDir, 'photos.json'));

  Future<List<Photo>> load() async {
    final map = await _store.readMap(_file);
    final list = map?['photos'];
    if (list is! List) return const [];
    final out = <Photo>[];
    for (final e in list) {
      try {
        out.add(Photo.fromJson((e as Map).cast<String, dynamic>()));
      } catch (e) {
        appLog.warning('跳过坏照片元数据: $e');
      }
    }
    return out;
  }

  Future<void> save(List<Photo> photos) => _store.writeMap(_file, {
        'schema_version': 1,
        'photos': photos.map((e) => e.toJson()).toList(),
      });

  /// 导入一张照片：复制进 `attachments/<年>/<sha1前8>-<原名>`，读取尺寸。
  Future<Photo?> importFile(File source) async {
    try {
      final bytes = await source.readAsBytes();
      final hash = sha1OfBytes(bytes);
      final baseName = p.basename(source.path);
      final year = DateTime.now().year.toString();
      final rel = p
          .join(SyncLayout.attachmentsDir, year, '${hash.substring(0, 8)}-$baseName')
          .replaceAll(r'\', '/');
      final target = File(p.join(rootPath, rel));
      if (!await target.exists()) {
        await writeBytesAtomic(target.path, bytes);
      }
      final size = await _imageSize(bytes);
      DateTime? takenAt;
      try {
        takenAt = (await source.stat()).modified;
      } catch (_) {}

      final now = DateTime.now();
      return Photo(
        id: _uuid.v4(),
        relPath: rel,
        filename: baseName,
        size: bytes.length,
        sha1: hash,
        width: size?.$1,
        height: size?.$2,
        takenAt: takenAt,
        tags: const [],
        createdAt: now,
        updatedAt: now,
      );
    } catch (e) {
      appLog.warning('导入照片失败: $e');
      return null;
    }
  }

  /// 从库里移除并删除文件（越界路径拒绝删除）。
  Future<void> deleteFile(Photo photo) async {
    final abs = resolveWithinRoot(rootPath, photo.relPath);
    if (abs == null) {
      appLog.warning('拒绝删除越界照片路径: ${photo.relPath}');
      return;
    }
    final file = File(abs);
    if (await file.exists()) await file.delete();
  }

  Future<(int, int)?> _imageSize(List<int> bytes) async {
    try {
      final codec = await ui.instantiateImageCodec(Uint8List.fromList(bytes));
      final frame = await codec.getNextFrame();
      final w = frame.image.width;
      final h = frame.image.height;
      frame.image.dispose();
      codec.dispose();
      return (w, h);
    } catch (_) {
      return null;
    }
  }
}
