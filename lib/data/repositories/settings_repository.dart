/// 同步根内 lifeline.yaml 的读写（不含密钥）。
library;

import 'dart:io';

import 'package:path/path.dart' as p;
import 'package:yaml/yaml.dart';
import 'package:yaml_writer/yaml_writer.dart';

import '../../core/constants.dart';
import '../../core/utils/file_utils.dart';
import '../models/app_settings.dart';

class SettingsRepository {
  SettingsRepository(this.rootPath);

  final String rootPath;

  File get _file => File(p.join(rootPath, SyncLayout.configFile));

  Future<AppSettings> load() async {
    if (!await _file.exists()) return AppSettings.initial();
    try {
      final node = loadYaml(await _file.readAsString());
      if (node is Map) {
        return AppSettings.fromJson(node.cast<String, dynamic>());
      }
      return AppSettings.initial();
    } catch (_) {
      return AppSettings.initial();
    }
  }

  Future<void> save(AppSettings settings) => writeStringAtomic(
        _file.path,
        YamlWriter().write(settings.toJson()),
      );
}
