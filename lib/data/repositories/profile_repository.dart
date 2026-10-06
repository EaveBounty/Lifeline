/// Profile 单例仓库：读写 data/profile.json。
library;

import 'dart:io';

import 'package:path/path.dart' as p;

import '../../core/constants.dart';
import '../json_store/json_file_store.dart';
import '../models/profile.dart';

class ProfileRepository {
  ProfileRepository(this.rootPath);

  final String rootPath;
  final JsonFileStore _store = JsonFileStore();

  File get _file =>
      File(p.join(rootPath, SyncLayout.dataDir, SyncLayout.profileFile));

  Future<Profile> load() async {
    final map = await _store.readMap(_file);
    if (map == null) return Profile.empty();
    try {
      return Profile.fromJson(map);
    } catch (_) {
      return Profile.empty();
    }
  }

  Future<void> save(Profile profile) =>
      _store.writeMap(_file, profile.copyWith(updatedAt: DateTime.now()).toJson());

  Future<Profile> setField(
    String section,
    String key,
    ProfileField field,
  ) async {
    final profile = await load();
    final sections = _cloneSections(profile.sections);
    (sections[section] ??= {})[key] = field;
    final next = profile.copyWith(sections: sections);
    await save(next);
    return next;
  }

  Future<Profile> removeField(String section, String key) async {
    final profile = await load();
    final sections = _cloneSections(profile.sections);
    sections[section]?.remove(key);
    if (sections[section]?.isEmpty ?? false) sections.remove(section);
    final next = profile.copyWith(sections: sections);
    await save(next);
    return next;
  }

  Future<Profile> upsertSection(
    String section,
    Map<String, ProfileField> fields,
  ) async {
    final profile = await load();
    final sections = _cloneSections(profile.sections);
    (sections[section] ??= {}).addAll(fields);
    final next = profile.copyWith(sections: sections);
    await save(next);
    return next;
  }

  Map<String, Map<String, ProfileField>> _cloneSections(
    Map<String, Map<String, ProfileField>> source,
  ) =>
      source.map((k, v) => MapEntry(k, Map<String, ProfileField>.from(v)));
}
