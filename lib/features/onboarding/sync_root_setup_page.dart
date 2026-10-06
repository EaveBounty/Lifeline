/// 首启：让用户亲自选择「同步文件夹」位置。
///
/// 铁律：App 绝不擅自创建目录；只有用户选定且确认后才初始化。
library;

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/constants.dart';
import '../../data/providers.dart';
import '../../data/repositories/root_manager.dart';
import 'sync_guide_page.dart';

class SyncRootSetupPage extends ConsumerStatefulWidget {
  const SyncRootSetupPage({super.key});

  @override
  ConsumerState<SyncRootSetupPage> createState() => _SyncRootSetupPageState();
}

class _SyncRootSetupPageState extends ConsumerState<SyncRootSetupPage> {
  bool _busy = false;

  Future<void> _pick() async {
    setState(() => _busy = true);
    try {
      final path = await FilePicker.getDirectoryPath(
        dialogTitle: '选择 Lifeline 同步文件夹',
      );
      if (path == null) return;
      await _handlePath(path);
    } catch (e) {
      _snack('选择失败：$e');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _handlePath(String path) async {
    final ctrl = ref.read(syncRootProvider.notifier);
    final probe = await ctrl.probe(path);

    switch (probe) {
      case RootProbe.initialized:
        final r = await ctrl.attach(path);
        r.when(
          ok: (_) => _snack('已挂载同步根'),
          err: (m, _) => _snack(m),
        );
        break;
      case RootProbe.empty:
        final ok = await _confirm(
          '在此文件夹初始化？',
          '将创建 Lifeline 的数据结构（data/、attachments/、配置文件等）。'
          '不会删除任何已有内容。\n\n$path',
        );
        if (ok) {
          final r = await ctrl.initializeAndAttach(path);
          r.when(
            ok: (_) => _snack('初始化完成'),
            err: (m, _) => _snack(m),
          );
        }
        break;
      case RootProbe.foreign:
        final ok = await _confirm(
          '该文件夹非空且不是 Lifeline 同步根',
          '继续将在此创建 Lifeline 结构并与现有文件共存（不删除已有文件）。'
          '建议改选一个专用空文件夹。\n\n$path',
        );
        if (ok) {
          final r = await ctrl.initializeAndAttach(path);
          r.when(
            ok: (_) => _snack('初始化完成'),
            err: (m, _) => _snack(m),
          );
        }
        break;
      case RootProbe.notDirectory:
        _snack('路径不存在或不是文件夹');
        break;
    }
  }

  Future<bool> _confirm(String title, String body) async {
    final res = await showDialog<bool>(
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
    return res ?? false;
  }

  void _snack(String msg) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg)));
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;

    return Scaffold(
      body: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 620),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Icon(Icons.all_inclusive, size: 40, color: scheme.primary),
                    const SizedBox(width: 12),
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('${AppInfo.nameEn} · ${AppInfo.nameZh}',
                            style: theme.textTheme.headlineSmall),
                        Text(AppInfo.tagline,
                            style: TextStyle(color: scheme.onSurfaceVariant)),
                      ],
                    ),
                  ],
                ),
                const SizedBox(height: 28),
                Text('选择同步文件夹', style: theme.textTheme.titleLarge),
                const SizedBox(height: 8),
                Text(
                  'Lifeline 的所有数据与配置都存放在您指定的一个文件夹里，与软件本身解耦。'
                  '您可以把这个文件夹用 Syncthing / WebDAV / Git 在设备间同步——软件只负责读写，不做同步。',
                  style: TextStyle(color: scheme.onSurfaceVariant, height: 1.5),
                ),
                const SizedBox(height: 20),
                Card(
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const _Bullet('数据以 JSON/YAML 纯文本保存，可 diff、可手动编辑。'),
                        const _Bullet('附件按相对路径索引，随文件夹一起同步。'),
                        const _Bullet('删除索引文件可由 JSON 100% 重建。'),
                        const _Bullet('不会自动新建或改动您未选择的任何目录。'),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 24),
                Row(
                  children: [
                    FilledButton.icon(
                      onPressed: _busy ? null : _pick,
                      icon: _busy
                          ? const SizedBox(
                              width: 18,
                              height: 18,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            )
                          : const Icon(Icons.folder_open),
                      label: Text(_busy ? '处理中…' : '选择同步文件夹'),
                    ),
                    const SizedBox(width: 12),
                    TextButton.icon(
                      onPressed: () => Navigator.of(context).push(
                        MaterialPageRoute(builder: (_) => const SyncGuidePage()),
                      ),
                      icon: const Icon(Icons.sync_alt),
                      label: const Text('同步方式指南'),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _Bullet extends StatelessWidget {
  const _Bullet(this.text);
  final String text;
  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Padding(
            padding: EdgeInsets.only(top: 3),
            child: Icon(Icons.check_circle_outline, size: 18),
          ),
          const SizedBox(width: 8),
          Expanded(child: Text(text, style: const TextStyle(height: 1.4))),
        ],
      ),
    );
  }
}
