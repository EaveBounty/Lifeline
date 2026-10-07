/// 更新检查 provider 与启动时检查逻辑。
library;

import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'update_service.dart';

final updateServiceProvider = Provider<UpdateService>((ref) => UpdateService());

/// 检查是否有「应提醒」的新版本（已忽略该版本则返回 null）。
Future<UpdateInfo?> checkForUpdate({bool ignoreSkip = false}) async {
  final res = await UpdateService().check();
  final info = res.valueOrNull;
  if (info == null || !info.hasUpdate) return null;
  if (!ignoreSkip) {
    final skip = await UpdatePrefs.skippedVersion();
    if (skip == info.latestVersion) return null;
  }
  return info;
}
