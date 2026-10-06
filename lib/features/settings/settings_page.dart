/// 设置页：外观、同步、AI、数据、关于。
library;

import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../core/constants.dart';
import '../../core/widgets/common.dart';
import '../../data/models/ai_provider.dart';
import '../../data/models/app_settings.dart';
import '../../data/models/profile_record.dart';
import '../../data/models/record_category.dart';
import '../../data/providers.dart';

/// 版本号：与 pubspec.yaml 的 version 保持一致（未引入 package_info_plus）。
const String _appVersion = '0.1.0+1';
const String _githubUrl = 'https://github.com/EaveBounty/Lifeline';
const String _license = 'PolyForm Noncommercial 1.0.0';

class SettingsPage extends ConsumerStatefulWidget {
  const SettingsPage({super.key});

  @override
  ConsumerState<SettingsPage> createState() => _SettingsPageState();
}

class _SettingsPageState extends ConsumerState<SettingsPage> {
  bool _rebuilding = false;

  Future<void> _save(AppSettings settings) =>
      ref.read(settingsProvider.notifier).save(settings);

  void _snack(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context)
        .showSnackBar(SnackBar(content: Text(message)));
  }

  Future<bool> _confirm(String title, String body) async {
    final result = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(title),
        content: Text(body),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('取消'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('确认'),
          ),
        ],
      ),
    );
    return result ?? false;
  }

  /// 桌面端调系统文件管理器；移动端仅提示路径。
  Future<void> _openFolder(String path) async {
    if (Platform.isAndroid || Platform.isIOS) {
      _snack('请在文件管理器中打开该文件夹：\n$path');
      return;
    }
    try {
      if (Platform.isWindows) {
        await Process.run('explorer', [path]);
      } else if (Platform.isMacOS) {
        await Process.run('open', [path]);
      } else {
        await Process.run('xdg-open', [path]);
      }
    } catch (e) {
      if (mounted) _snack('无法打开文件夹：$e');
    }
  }

  Future<void> _switchRoot() async {
    final ok = await _confirm(
      '切换同步根？',
      '将解除当前同步根的挂载并返回首启页。原文件夹中的数据不会被删除，之后可重新选择或挂载。',
    );
    if (!ok) return;
    // 解除后 app.dart 检测到 hasRoot=false 会自动显示首启页，无需手动导航。
    await ref.read(syncRootProvider.notifier).detach();
  }

  Future<void> _rebuildIndex() async {
    setState(() => _rebuilding = true);
    try {
      await ref.read(recordsProvider.notifier).rebuildIndex();
      _snack('索引重建完成');
    } catch (e) {
      _snack('重建失败：$e');
    } finally {
      if (mounted) setState(() => _rebuilding = false);
    }
  }

  Future<void> _openExternal(String url) async {
    final uri = Uri.tryParse(url);
    if (uri == null) return;
    final launched = await launchUrl(uri, mode: LaunchMode.externalApplication);
    if (!launched && mounted) _snack('无法打开链接：$url');
  }

  AiProvider? _defaultProvider(AppSettings settings) {
    final id = settings.defaultAiProviderId;
    if (id == null) return null;
    for (final p in settings.providers) {
      if (p.id == id) return p;
    }
    return null;
  }

  @override
  Widget build(BuildContext context) {
    final settingsAsync = ref.watch(settingsProvider);
    return Scaffold(
      appBar: AppBar(title: const Text('设置')),
      body: settingsAsync.when(
        loading: () => const LoadingView(),
        error: (e, _) => ErrorView(
          error: e,
          onRetry: () => ref.invalidate(settingsProvider),
        ),
        data: (settings) => _buildBody(context, settings),
      ),
    );
  }

  Widget _buildBody(BuildContext context, AppSettings settings) {
    final sync = ref.watch(syncRootProvider);
    final records = ref.watch(recordsProvider).value ?? const <ProfileRecord>[];
    return Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 860),
        child: ListView(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 32),
          children: [
            _appearance(settings),
            const SizedBox(height: 4),
            _sync(sync),
            const SizedBox(height: 4),
            _ai(settings),
            const SizedBox(height: 4),
            _data(records),
            const SizedBox(height: 4),
            _about(),
          ],
        ),
      ),
    );
  }

  Widget _appearance(AppSettings settings) => SectionCard(
        title: '外观',
        icon: Icons.palette_outlined,
        child: Column(
          children: [
            DropdownButtonFormField<String>(
              initialValue: settings.themeMode,
              decoration: const InputDecoration(labelText: '主题模式'),
              items: const [
                DropdownMenuItem(value: 'system', child: Text('跟随系统')),
                DropdownMenuItem(value: 'light', child: Text('浅色')),
                DropdownMenuItem(value: 'dark', child: Text('深色')),
              ],
              onChanged: (v) {
                if (v != null) _save(settings.copyWith(themeMode: v));
              },
            ),
            const SizedBox(height: 12),
            DropdownButtonFormField<String>(
              initialValue: settings.language,
              decoration: const InputDecoration(labelText: '界面语言'),
              items: const [
                DropdownMenuItem(value: 'zh', child: Text('简体中文')),
                DropdownMenuItem(value: 'en', child: Text('English')),
              ],
              onChanged: (v) {
                if (v != null) _save(settings.copyWith(language: v));
              },
            ),
          ],
        ),
      );

  Widget _sync(SyncRootState sync) {
    final theme = Theme.of(context);
    final path = sync.path;
    return SectionCard(
      title: '同步',
      icon: Icons.sync,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('当前同步根', style: TextStyle(fontWeight: FontWeight.w600)),
          const SizedBox(height: 6),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: theme.colorScheme.surfaceContainerHighest,
              borderRadius: BorderRadius.circular(8),
            ),
            child: SelectableText(
              path ?? '（未挂载）',
              style: const TextStyle(fontSize: 13),
            ),
          ),
          const SizedBox(height: 12),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              OutlinedButton.icon(
                onPressed: path == null ? null : () => _openFolder(path),
                icon: const Icon(Icons.folder_open),
                label: const Text('打开文件夹'),
              ),
              OutlinedButton.icon(
                onPressed: _switchRoot,
                icon: const Icon(Icons.drive_file_move_outline),
                label: const Text('切换同步根'),
              ),
              TextButton.icon(
                onPressed: () => context.push('/sync'),
                icon: const Icon(Icons.help_outline),
                label: const Text('同步方式指南'),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            'Lifeline 不做同步，只读写此文件夹；请用 Syncthing / WebDAV / Git 在设备间同步。',
            style: TextStyle(color: theme.colorScheme.onSurfaceVariant, height: 1.4),
          ),
        ],
      ),
    );
  }

  Widget _ai(AppSettings settings) {
    final theme = Theme.of(context);
    final defaultProvider = _defaultProvider(settings);
    return SectionCard(
      title: 'AI / 模型厂商',
      icon: Icons.smart_toy_outlined,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          ListTile(
            contentPadding: EdgeInsets.zero,
            title: const Text('默认 Provider'),
            subtitle: Text(defaultProvider?.name ?? '未设置'),
            trailing: FilledButton.tonal(
              onPressed: () => context.push('/settings/ai'),
              child: const Text('管理'),
            ),
          ),
          Text(
            '密钥优先存系统密钥库，不写入同步 YAML；导出/录入等 AI 功能使用默认 Provider。',
            style: TextStyle(color: theme.colorScheme.onSurfaceVariant, height: 1.4),
          ),
        ],
      ),
    );
  }

  Widget _data(List<ProfileRecord> records) {
    final theme = Theme.of(context);
    final counts = <RecordCategory, int>{};
    for (final r in records) {
      counts[r.category] = (counts[r.category] ?? 0) + 1;
    }
    final nonZero =
        RecordCategory.values.where((c) => (counts[c] ?? 0) > 0).toList();
    return SectionCard(
      title: '数据',
      icon: Icons.storage_outlined,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              FilledButton.tonalIcon(
                onPressed: _rebuilding ? null : _rebuildIndex,
                icon: _rebuilding
                    ? const SizedBox(
                        width: 16,
                        height: 16,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Icon(Icons.refresh),
                label: Text(_rebuilding ? '重建中…' : '重建索引'),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  '索引可由 JSON 数据 100% 重建。',
                  style: TextStyle(color: theme.colorScheme.onSurfaceVariant),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Text('记录数：共 ${records.length} 条',
              style: const TextStyle(fontWeight: FontWeight.w600)),
          const SizedBox(height: 6),
          if (nonZero.isEmpty)
            Text('暂无记录',
                style: TextStyle(color: theme.colorScheme.onSurfaceVariant))
          else
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: nonZero
                  .map((c) => Chip(
                        label: Text('${c.labelZh} ${counts[c]}'),
                        visualDensity: VisualDensity.compact,
                        materialTapTargetSize:
                            MaterialTapTargetSize.shrinkWrap,
                      ))
                  .toList(),
            ),
        ],
      ),
    );
  }

  Widget _about() {
    final theme = Theme.of(context);
    return SectionCard(
      title: '关于',
      icon: Icons.info_outline,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _aboutRow('名称', '${AppInfo.nameZh}（${AppInfo.nameEn}）'),
          _aboutRow('版本', _appVersion),
          _aboutRow('许可', _license),
          _aboutRow('版权', AppInfo.authorZh),
          const SizedBox(height: 6),
          InkWell(
            onTap: () => _openExternal(_githubUrl),
            borderRadius: BorderRadius.circular(6),
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: 6, horizontal: 4),
              child: Row(
                children: [
                  Icon(Icons.link, size: 18, color: theme.colorScheme.primary),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      _githubUrl,
                      style: TextStyle(
                        color: theme.colorScheme.primary,
                        decoration: TextDecoration.underline,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 8),
          Text(
            '本软件以 PolyForm Noncommercial 1.0.0 许可发布，禁止商业用途；'
            '商业授权请联系版权方。内嵌第三方资产（Typst 二进制、字体、模板）许可详见 NOTICE。',
            style: TextStyle(
              color: theme.colorScheme.onSurfaceVariant,
              height: 1.5,
              fontSize: 12.5,
            ),
          ),
        ],
      ),
    );
  }

  Widget _aboutRow(String label, String value) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 3),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 72,
            child: Text(label,
                style: TextStyle(color: theme.colorScheme.onSurfaceVariant)),
          ),
          Expanded(child: Text(value)),
        ],
      ),
    );
  }
}
