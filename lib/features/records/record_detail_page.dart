/// 记录详情页：展示全部字段、附件缩略与全屏预览，支持编辑/删除。
library;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/widgets/common.dart';
import '../../data/models/profile_record.dart';
import '../../data/models/record_category.dart';
import '../../data/providers.dart';
import '../attachments/attachment_preview.dart';

class RecordDetailPage extends ConsumerWidget {
  const RecordDetailPage({super.key, required this.recordId});

  final String recordId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final async = ref.watch(recordsProvider);
    return async.when(
      loading: () => Scaffold(
        appBar: AppBar(),
        body: const LoadingView(message: '正在载入记录…'),
      ),
      error: (e, _) => Scaffold(
        appBar: AppBar(),
        body: ErrorView(
          error: e,
          onRetry: () => ref.invalidate(recordsProvider),
        ),
      ),
      data: (list) {
        ProfileRecord? record;
        for (final r in list) {
          if (r.id == recordId) {
            record = r;
            break;
          }
        }
        if (record == null) {
          return Scaffold(
            appBar: AppBar(title: const Text('记录详情')),
            body: const EmptyState(
              icon: Icons.search_off,
              title: '记录不存在',
              message: '该记录可能已被删除。',
            ),
          );
        }
        return _DetailView(record: record);
      },
    );
  }
}

class _DetailView extends ConsumerWidget {
  const _DetailView({required this.record});

  final ProfileRecord record;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final root = ref.watch(syncRootProvider).path;
    final categories = ref.watch(categoriesProvider);
    final def = resolveCategory(categories, record.categorySlug);

    return Scaffold(
      appBar: AppBar(
        title: Text(def.label),
        actions: [
          IconButton(
            tooltip: '编辑',
            icon: const Icon(Icons.edit_outlined),
            onPressed: () => context.push('/records/${record.id}/edit'),
          ),
          IconButton(
            tooltip: '删除',
            icon: const Icon(Icons.delete_outline),
            onPressed: () => _confirmDelete(context, ref),
          ),
          const SizedBox(width: 4),
        ],
      ),
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 900),
          child: ListView(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 32),
            children: [
              _headerCard(theme, def),
              const SizedBox(height: 12),
              if (record.description.trim().isNotEmpty)
                _section(
                  title: '描述',
                  icon: Icons.notes,
                  child: Text(record.description,
                      style: const TextStyle(height: 1.6)),
                ),
              if (record.highlights.isNotEmpty)
                _section(
                  title: '亮点',
                  icon: Icons.star_outline,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      for (final h in record.highlights)
                        Padding(
                          padding: const EdgeInsets.symmetric(vertical: 3),
                          child: Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Padding(
                                padding: EdgeInsets.only(top: 6),
                                child: Icon(Icons.circle, size: 6),
                              ),
                              const SizedBox(width: 8),
                              Expanded(
                                  child: Text(h,
                                      style: const TextStyle(height: 1.5))),
                            ],
                          ),
                        ),
                    ],
                  ),
                ),
              if (record.tags.isNotEmpty)
                _section(
                  title: '标签',
                  icon: Icons.sell_outlined,
                  child: TagChips(tags: record.tags),
                ),
              if (record.fields.isNotEmpty)
                _section(
                  title: '自定义字段',
                  icon: Icons.list_alt,
                  child: Column(
                    children: [
                      for (final entry in record.fields.entries)
                        _kvRow(theme, entry.key, '${entry.value}'),
                    ],
                  ),
                ),
              if (record.links.isNotEmpty)
                _section(
                  title: '链接',
                  icon: Icons.link,
                  child: Column(
                    children: [
                      for (final link in record.links)
                        ListTile(
                          dense: true,
                          contentPadding: EdgeInsets.zero,
                          leading: const Icon(Icons.open_in_new, size: 18),
                          title: Text(link.label.isEmpty
                              ? link.url
                              : link.label),
                          subtitle: link.label.isEmpty ? null : Text(link.url),
                        ),
                    ],
                  ),
                ),
              if (record.attachments.isNotEmpty)
                _section(
                  title: '附件',
                  icon: Icons.attach_file,
                  child: root == null
                      ? Text('尚未设置同步根，无法显示附件。',
                          style: TextStyle(
                              color: theme.colorScheme.onSurfaceVariant))
                      : Wrap(
                          spacing: 10,
                          runSpacing: 10,
                          children: [
                            for (final rel in record.attachments)
                              AttachmentThumb(
                                file: attachmentFileOf(root, rel),
                                relPath: rel,
                                size: 100,
                                onTap: () => showAttachmentPreview(
                                  context,
                                  file: attachmentFileOf(root, rel),
                                  relPath: rel,
                                ),
                              ),
                          ],
                        ),
                ),
              const SizedBox(height: 12),
              _metaCard(theme),
            ],
          ),
        ),
      ),
    );
  }

  Widget _headerCard(ThemeData theme, CategoryDef def) {
    final date = formatDateRange(record.startDate, record.endDate);
    final subtitle = <String>[
      if ((record.organization ?? '').trim().isNotEmpty)
        record.organization!.trim(),
      if ((record.role ?? '').trim().isNotEmpty) record.role!.trim(),
    ].join(' · ');
    return SectionCard(
      title: record.title.isEmpty ? '（无标题）' : record.title,
      icon: categoryIcon(def.icon),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (subtitle.isNotEmpty)
            Text(subtitle,
                style: TextStyle(color: theme.colorScheme.primary)),
          if ((record.location ?? '').trim().isNotEmpty)
            Padding(
              padding: const EdgeInsets.only(top: 4),
              child: Row(
                children: [
                  const Icon(Icons.place_outlined, size: 15),
                  const SizedBox(width: 4),
                  Text(record.location!),
                ],
              ),
            ),
          if (date.isNotEmpty)
            Padding(
              padding: const EdgeInsets.only(top: 4),
              child: Row(
                children: [
                  const Icon(Icons.event_outlined, size: 15),
                  const SizedBox(width: 4),
                  Text(date),
                ],
              ),
            ),
        ],
      ),
    );
  }

  Widget _metaCard(ThemeData theme) {
    final style =
        TextStyle(fontSize: 12, color: theme.colorScheme.onSurfaceVariant);
    final sourceType = switch (record.source.type) {
      'ai' => 'AI 录入',
      'import' => '导入',
      _ => '手动录入',
    };
    return SectionCard(
      title: '元信息',
      icon: Icons.info_outline,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _metaLine(theme, '来源', sourceType),
          if ((record.source.ref ?? '').trim().isNotEmpty)
            _metaLine(theme, '来源引用', record.source.ref!),
          _metaLine(theme, '状态', record.status == 'archived' ? '已归档' : '活跃'),
          if ((record.ai.model ?? '').trim().isNotEmpty)
            _metaLine(theme, 'AI 模型', record.ai.model!),
          _metaLine(theme, '创建时间', _fmt(record.createdAt)),
          _metaLine(theme, '更新时间', _fmt(record.updatedAt)),
          Padding(
            padding: const EdgeInsets.only(top: 6),
            child: Text('id: ${record.id}', style: style),
          ),
        ],
      ),
    );
  }

  Widget _metaLine(ThemeData theme, String label, String value) => Padding(
        padding: const EdgeInsets.symmetric(vertical: 2),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            SizedBox(
              width: 80,
              child: Text(label, style: theme.textTheme.labelMedium),
            ),
            Expanded(child: Text(value)),
          ],
        ),
      );

  Widget _kvRow(ThemeData theme, String key, String value) => Padding(
        padding: const EdgeInsets.symmetric(vertical: 3),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            SizedBox(
              width: 120,
              child: Text(key,
                  style: TextStyle(color: theme.colorScheme.onSurfaceVariant)),
            ),
            Expanded(child: Text(value)),
          ],
        ),
      );

  Widget _section({
    required String title,
    required IconData icon,
    required Widget child,
  }) =>
      Padding(
        padding: const EdgeInsets.only(bottom: 12),
        child: SectionCard(title: title, icon: icon, child: child),
      );

  Future<void> _confirmDelete(BuildContext context, WidgetRef ref) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('删除记录'),
        content: Text('确定删除「${record.title}」吗？此操作不可撤销。'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: const Text('取消'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(ctx).pop(true),
            child: const Text('删除'),
          ),
        ],
      ),
    );
    if (ok != true) return;
    await ref.read(recordsProvider.notifier).delete(record.id);
    if (context.mounted) context.pop();
  }

  static String _fmt(DateTime t) =>
      '${t.year}-${t.month.toString().padLeft(2, '0')}-${t.day.toString().padLeft(2, '0')} '
      '${t.hour.toString().padLeft(2, '0')}:${t.minute.toString().padLeft(2, '0')}';
}
