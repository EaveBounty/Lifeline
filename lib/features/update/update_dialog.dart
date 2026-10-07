/// 「发现新版本」对话框：展示版本/更新说明，提供下载并安装与提醒偏好。
library;

import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../services/update/update_service.dart';

/// 展示更新对话框。返回后由调用方决定是否刷新。
Future<void> showUpdateDialog(BuildContext context, UpdateInfo info) async {
  var skip = false;
  final downloaded = await showDialog<bool>(
    context: context,
    builder: (ctx) {
      final theme = Theme.of(ctx);
      return StatefulBuilder(
        builder: (ctx, setState) => AlertDialog(
          title: Text('发现新版本 v${info.latestVersion}'),
          content: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 520, maxHeight: 460),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('当前版本 v${info.currentVersion} → 最新 v${info.latestVersion}',
                    style: theme.textTheme.bodyMedium),
                const SizedBox(height: 8),
                if (info.notes.trim().isNotEmpty) ...[
                  Text('更新说明', style: theme.textTheme.labelLarge),
                  const SizedBox(height: 4),
                  Flexible(
                    child: SingleChildScrollView(
                      child: Text(info.notes.trim(),
                          style: const TextStyle(height: 1.45, fontSize: 12.5)),
                    ),
                  ),
                ],
                const SizedBox(height: 8),
                CheckboxListTile(
                  contentPadding: EdgeInsets.zero,
                  dense: true,
                  value: skip,
                  onChanged: (v) => setState(() => skip = v ?? false),
                  title: const Text('此版本不再提醒'),
                  subtitle: const Text('勾选＝只提示这一次；不勾＝每次启动都提醒'),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('稍后'),
            ),
            FilledButton.icon(
              onPressed: () {
                if (skip) UpdatePrefs.setSkippedVersion(info.latestVersion);
                Navigator.pop(ctx, true);
              },
              icon: const Icon(Icons.download_outlined),
              label: const Text('下载并安装'),
            ),
          ],
        ),
      );
    },
  );

  if (downloaded == true) {
    final uri = Uri.tryParse(info.downloadUrl);
    if (uri != null) {
      try {
        await launchUrl(uri, mode: LaunchMode.externalApplication);
      } catch (_) {
        // 打开失败时静默。
      }
    }
  }
}
