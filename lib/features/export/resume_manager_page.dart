/// 简历库：预览 / 分享 / 打开 / 评估 / 按评估修订 / 重新生成 / 备注 / 删除。
library;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:open_filex/open_filex.dart';
import 'package:path/path.dart' as p;

import '../../core/platform/io_platform.dart';
import '../../core/widgets/common.dart';
import '../../data/models/export_request.dart';
import '../../data/providers.dart';
import '../../services/render/templates.dart';
import 'resume_preview_page.dart';

class ResumeManagerPage extends ConsumerWidget {
  const ResumeManagerPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final library = ref.watch(resumeLibraryProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('简历库'),
        actions: [
          IconButton(
            tooltip: '刷新',
            icon: const Icon(Icons.refresh),
            onPressed: () => ref.read(resumeLibraryProvider.notifier).refresh(),
          ),
          IconButton(
            tooltip: '新建定向简历',
            icon: const Icon(Icons.add),
            onPressed: () => context.push('/export'),
          ),
        ],
      ),
      body: library.when(
        loading: () => const LoadingView(message: '正在载入简历库…'),
        error: (e, _) => ErrorView(
          error: e,
          onRetry: () => ref.invalidate(resumeLibraryProvider),
        ),
        data: (list) {
          if (list.isEmpty) {
            return EmptyState(
              icon: Icons.folder_special_outlined,
              title: '还没有定向简历',
              message: '填写导出问卷，AI 将结合目标岗位自动裁剪并生成 PDF / DOCX / Markdown。',
              action: FilledButton.icon(
                onPressed: () => context.push('/export'),
                icon: const Icon(Icons.auto_awesome),
                label: const Text('去生成'),
              ),
            );
          }
          return ListView.builder(
            padding: const EdgeInsets.symmetric(vertical: 8),
            itemCount: list.length,
            itemBuilder: (_, i) => _ResumeTile(meta: list[i]),
          );
        },
      ),
    );
  }
}

class _ResumeTile extends ConsumerWidget {
  const _ResumeTile({required this.meta});
  final ResumeMeta meta;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final subtitle = [meta.targetRole, meta.targetCompany]
        .where((e) => e.trim().isNotEmpty)
        .join(' · ');
    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      child: ListTile(
        leading: Icon(_statusIcon(meta.status), color: theme.colorScheme.primary),
        onTap: meta.files.containsKey('pdf') ? () => _preview(context, ref) : null,
        title: Row(
          children: [
            Expanded(
              child: Text(meta.name, overflow: TextOverflow.ellipsis),
            ),
            if (meta.evaluation != null) ...[
              const SizedBox(width: 8),
              _ScoreBadge(
                objective: meta.evaluation!.objective.overall,
                fit: meta.evaluation!.fit.fitScore,
                ai: meta.evaluation!.aiAssisted,
              ),
            ],
          ],
        ),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (subtitle.isNotEmpty) Text(subtitle),
            Text(
              '${_statusLabel(meta.status)} · ${_fmt(meta.updatedAt)}'
              ' · ${ResumeTemplates.byId(meta.templateId ?? meta.request?.templateId).name}'
              '${meta.files.isEmpty ? '' : ' · ${meta.files.keys.join('/')}'}',
              style: TextStyle(color: theme.colorScheme.onSurfaceVariant, fontSize: 12),
            ),
          ],
        ),
        trailing: PopupMenuButton<String>(
          onSelected: (action) => _onAction(context, ref, action),
          itemBuilder: (_) => [
            if (meta.files.containsKey('pdf'))
              const PopupMenuItem(value: 'preview', child: Text('预览 PDF')),
            const PopupMenuItem(value: 'share', child: Text('分享')),
            const PopupMenuItem(value: 'open', child: Text('用系统应用打开')),
            const PopupMenuDivider(),
            PopupMenuItem(
              value: 'eval',
              child: Text(meta.evaluation == null ? '评估' : '查看评估'),
            ),
            const PopupMenuItem(value: 'revise', child: Text('按评估修订')),
            const PopupMenuItem(value: 'regen', child: Text('重新生成（更新本份）')),
            const PopupMenuDivider(),
            const PopupMenuItem(value: 'notes', child: Text('编辑备注')),
            const PopupMenuItem(value: 'delete', child: Text('删除')),
          ],
        ),
      ),
    );
  }

  Future<void> _onAction(
    BuildContext context,
    WidgetRef ref,
    String action,
  ) async {
    switch (action) {
      case 'preview':
        return _preview(context, ref);
      case 'share':
        return _share(context, ref);
      case 'open':
        return _openFile(context, ref);
      case 'eval':
      case 'revise':
        context.push('/resumes/eval', extra: meta);
        return;
      case 'regen':
        context.push('/export', extra: meta);
        return;
      case 'notes':
        return _editNotes(context, ref);
      case 'delete':
        return _confirmDelete(context, ref);
    }
  }

  File? _primaryFile(WidgetRef ref) {
    final root = ref.read(syncRootProvider).path;
    if (root == null || meta.files.isEmpty) return null;
    final rel = meta.files['pdf'] ??
        meta.files['docx'] ??
        meta.files.values.first;
    return File(p.join(root, rel));
  }

  Future<void> _preview(BuildContext context, WidgetRef ref) async {
    final messenger = ScaffoldMessenger.of(context);
    final root = ref.read(syncRootProvider).path;
    final rel = meta.files['pdf'];
    if (root == null || rel == null) {
      messenger.showSnackBar(const SnackBar(content: Text('没有可预览的 PDF')));
      return;
    }
    final file = File(p.join(root, rel));
    if (!await file.exists()) {
      messenger.showSnackBar(const SnackBar(content: Text('文件不存在，请重新生成')));
      return;
    }
    if (!context.mounted) return;
    await Navigator.of(context).push(MaterialPageRoute<void>(
      builder: (_) => ResumePreviewPage(title: meta.name, file: file),
    ));
  }

  Future<void> _share(BuildContext context, WidgetRef ref) async {
    final messenger = ScaffoldMessenger.of(context);
    final file = _primaryFile(ref);
    if (file == null || !await file.exists()) {
      messenger.showSnackBar(const SnackBar(content: Text('没有可分享的文件')));
      return;
    }
    await shareFile(file, text: meta.name);
  }

  Future<void> _openFile(BuildContext context, WidgetRef ref) async {
    final messenger = ScaffoldMessenger.of(context);
    final file = _primaryFile(ref);
    if (file == null || !await file.exists()) {
      messenger.showSnackBar(const SnackBar(content: Text('没有可打开的文件')));
      return;
    }
    final result = await OpenFilex.open(file.path);
    if (result.type != ResultType.done) {
      messenger.showSnackBar(SnackBar(content: Text('无法打开：${result.message}')));
    }
  }

  Future<void> _editNotes(BuildContext context, WidgetRef ref) async {
    final controller = TextEditingController(text: meta.notes);
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('编辑备注'),
        content: TextField(
          controller: controller,
          maxLines: 4,
          autofocus: true,
          decoration: const InputDecoration(
            hintText: '记录投递情况、改进点…',
            border: OutlineInputBorder(),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('取消'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('保存'),
          ),
        ],
      ),
    );
    if (ok == true) {
      await ref
          .read(resumeLibraryProvider.notifier)
          .saveMeta(meta.copyWith(notes: controller.text.trim()));
    }
    controller.dispose();
  }

  Future<void> _confirmDelete(BuildContext context, WidgetRef ref) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('删除这份简历？'),
        content: Text('将删除「${meta.name}」及其全部导出文件，无法撤销。'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('取消'),
          ),
          FilledButton(
            style: FilledButton.styleFrom(
              backgroundColor: Theme.of(ctx).colorScheme.error,
            ),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('删除'),
          ),
        ],
      ),
    );
    if (ok == true) {
      await ref.read(resumeLibraryProvider.notifier).delete(meta.id);
    }
  }

  static String _statusLabel(String status) => switch (status) {
        'pending' => '待生成',
        'generating' => '生成中',
        'generated' => '已生成',
        'needs_regen' => '待重生成',
        'archived' => '已归档',
        _ => status,
      };

  static IconData _statusIcon(String status) => switch (status) {
        'generated' => Icons.check_circle_outline,
        'generating' => Icons.hourglass_top,
        'needs_regen' => Icons.sync_problem,
        'archived' => Icons.archive_outlined,
        _ => Icons.schedule,
      };

  static String _fmt(DateTime t) =>
      '${t.year}-${t.month.toString().padLeft(2, '0')}-${t.day.toString().padLeft(2, '0')} '
      '${t.hour.toString().padLeft(2, '0')}:${t.minute.toString().padLeft(2, '0')}';
}

/// 列表项上的总分徽章：显示「适配/客观」两分（启发式或 AI）。
class _ScoreBadge extends StatelessWidget {
  const _ScoreBadge({required this.objective, required this.fit, required this.ai});
  final int objective;
  final int fit;
  final bool ai;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final color = objective >= 80
        ? Colors.green.shade600
        : objective >= 60
            ? Colors.orange.shade700
            : scheme.error;
    return Tooltip(
      message: '${ai ? 'AI' : '启发式'}评估：适配 $fit / 客观 $objective',
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.14),
          borderRadius: BorderRadius.circular(10),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (ai) ...[
              Icon(Icons.auto_awesome, size: 12, color: color),
              const SizedBox(width: 3),
            ],
            Text(
              '$fit/$objective',
              style: TextStyle(
                color: color,
                fontWeight: FontWeight.bold,
                fontSize: 12,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
