/// 自动更新：查询 GitHub Releases 最新版本并与本机版本比较。
///
/// 更新源：`https://github.com/EaveBounty/Lifeline` 的 Releases（公开）。
/// 检查失败一律静默（返回 [Err]，不打扰用户）。
library;

import 'package:dio/dio.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../core/platform/io_platform.dart';
import '../../core/result.dart';

/// 一次更新检查的结果。
class UpdateInfo {
  const UpdateInfo({
    required this.hasUpdate,
    required this.currentVersion,
    required this.latestVersion,
    required this.releaseUrl,
    this.assetUrl,
    this.notes = '',
  });

  final bool hasUpdate;
  final String currentVersion;
  final String latestVersion;

  /// Release 页面地址。
  final String releaseUrl;

  /// 针对当前平台的最优安装包直链（无则回退 [releaseUrl]）。
  final String? assetUrl;

  /// 更新说明（release body）。
  final String notes;

  /// 供「下载并安装」使用的最终地址。
  String get downloadUrl =>
      (assetUrl ?? '').trim().isEmpty ? releaseUrl : assetUrl!;
}

class UpdateService {
  UpdateService({Dio? dio})
      : _dio = dio ??
            Dio(BaseOptions(
              connectTimeout: const Duration(seconds: 15),
              receiveTimeout: const Duration(seconds: 20),
            ));

  final Dio _dio;

  static const String _repoApi =
      'https://api.github.com/repos/EaveBounty/Lifeline/releases/latest';

  Future<Result<UpdateInfo>> check() async {
    try {
      final info = await PackageInfo.fromPlatform();
      final current = info.version.trim();
      final resp = await _dio.get<dynamic>(
        _repoApi,
        options: Options(headers: {
          'Accept': 'application/vnd.github+json',
          'User-Agent': 'Lifeline-Updater',
        }),
      );
      final data = resp.data;
      if (data is! Map) return const Err('版本接口返回异常');
      final tag = '${data['tag_name'] ?? ''}'.trim();
      final latest = tag.replaceFirst(RegExp(r'^[vV]'), '');
      if (latest.isEmpty) return const Err('未获取到最新版本号');

      final assets = (data['assets'] as List?)
              ?.whereType<Map>()
              .map((e) => e.cast<String, dynamic>())
              .toList() ??
          const <Map<String, dynamic>>[];
      return Ok(UpdateInfo(
        hasUpdate: compareVersions(latest, current) > 0,
        currentVersion: current,
        latestVersion: latest,
        releaseUrl: '${data['html_url'] ?? 'https://github.com/EaveBounty/Lifeline/releases'}',
        assetUrl: _pickAsset(assets),
        notes: '${data['body'] ?? ''}',
      ));
    } catch (e) {
      return Err('检查更新失败：$e', e);
    }
  }

  /// 依据平台从 release 资产中挑选安装包直链。
  String? _pickAsset(List<Map<String, dynamic>> assets) {
    final names = <String>[];
    if (Platform.isAndroid) {
      names.addAll(['app-release.apk', 'app-arm64-v8a-release.apk']);
    } else if (Platform.isWindows) {
      names.add('lifeline-windows-x64.zip');
    } else if (Platform.isMacOS) {
      names.add('lifeline-macos.zip');
    } else if (Platform.isLinux) {
      names.add('lifeline-linux-x64.tar.gz');
    }
    for (final wanted in names) {
      for (final a in assets) {
        if ('${a['name']}' == wanted) {
          return a['browser_download_url'] as String?;
        }
      }
    }
    return null;
  }
}

/// 语义化版本比较：a>b 返回正，a<b 返回负，相等 0。容忍非数字段（按字符串兜底）。
int compareVersions(String a, String b) {
  List<int> parse(String v) => v
      .split('+')
      .first
      .split(RegExp(r'[.-]'))
      .map((e) => int.tryParse(e) ?? 0)
      .toList();
  final pa = parse(a);
  final pb = parse(b);
  final n = pa.length > pb.length ? pa.length : pb.length;
  for (var i = 0; i < n; i++) {
    final x = i < pa.length ? pa[i] : 0;
    final y = i < pb.length ? pb[i] : 0;
    if (x != y) return x - y;
  }
  return 0;
}

/// 「提醒偏好」：默认每次提醒；用户可选「此版本不再提醒」。
class UpdatePrefs {
  static const String _kSkip = 'update.skipped_version';
  static const String _kAuto = 'update.auto_check';

  static Future<String?> skippedVersion() async =>
      (await SharedPreferences.getInstance()).getString(_kSkip);

  static Future<void> setSkippedVersion(String? version) async {
    final sp = await SharedPreferences.getInstance();
    if (version == null || version.isEmpty) {
      await sp.remove(_kSkip);
    } else {
      await sp.setString(_kSkip, version);
    }
  }

  static Future<bool> autoCheckEnabled() async =>
      (await SharedPreferences.getInstance()).getBool(_kAuto) ?? true;

  static Future<void> setAutoCheck(bool enabled) async {
    final sp = await SharedPreferences.getInstance();
    await sp.setBool(_kAuto, enabled);
  }
}
