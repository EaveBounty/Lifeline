/// 本地 App 配置（不入同步根，纯本机偏好）。
///
/// 仅存同步根路径与最近打开时间；其余设置存同步根内的 lifeline.yaml。
library;

import 'package:shared_preferences/shared_preferences.dart';

class AppConfig {
  AppConfig._(this._prefs);

  final SharedPreferences _prefs;

  static const String _kSyncRoot = 'sync_root';
  static const String _kLastOpenedAt = 'last_opened_at';

  static Future<AppConfig> load() async =>
      AppConfig._(await SharedPreferences.getInstance());

  /// 已记住的同步根路径；无则 null。
  String? get syncRoot {
    final v = _prefs.getString(_kSyncRoot);
    return (v == null || v.isEmpty) ? null : v;
  }

  DateTime? get lastOpenedAt {
    final v = _prefs.getString(_kLastOpenedAt);
    return v == null ? null : DateTime.tryParse(v);
  }

  Future<void> setSyncRoot(String? path) async {
    if (path == null || path.isEmpty) {
      await _prefs.remove(_kSyncRoot);
    } else {
      await _prefs.setString(_kSyncRoot, path);
    }
  }

  Future<void> touchOpenedAt() =>
      _prefs.setString(_kLastOpenedAt, DateTime.now().toIso8601String());
}
