/// Android 存储权限：访问用户选择的「同步文件夹」需要外部存储访问权。
///
/// - Android ≤10：`READ/WRITE_EXTERNAL_STORAGE`。
/// - Android 11+：`MANAGE_EXTERNAL_STORAGE`（“所有文件访问”）。
/// 其他平台/Web 直接放行。
library;

import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:permission_handler/permission_handler.dart';

import 'io_platform.dart';

/// 请求外部存储访问权限；返回是否已获得。
Future<bool> ensureStorageAccess() async {
  if (kIsWeb || !Platform.isAndroid) return true;

  // Android 11+：优先「所有文件访问」。
  if (await Permission.manageExternalStorage.isGranted) return true;
  final manage = await Permission.manageExternalStorage.request();
  if (manage.isGranted) return true;

  // Android ≤10：常规存储权限。
  if (await Permission.storage.isGranted) return true;
  final storage = await Permission.storage.request();
  if (storage.isGranted) return true;

  return false;
}

/// 跳转系统设置，便于用户手动开启权限。
Future<void> openAppPermissionSettings() => openAppSettings();
