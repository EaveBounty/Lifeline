/// 信息记录列表页：按分类分组、搜索、筛选、导入导出。
library;

import 'dart:convert';
import 'dart:typed_data';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/platform/io_platform.dart';
import '../../core/widgets/common.dart';
import '../../data/models/profile_record.dart';
import '../../data/models/record_category.dart';
import '../../data/providers.dart';

class RecordsPage extends ConsumerWidget {
  const RecordsPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('信息记录'),
        actions: [
          IconButton(
            tooltip: '重建索引',
            icon: const Icon(Icons.sync),
            onPressed: () => _rebuildIndex(context, ref),
          ),
          IconButton(
            tooltip: '导入 JSON',
            icon: const Icon(Icons.file_upload_outlined),
            onPressed: () => _importJson(context, ref),
          ),
          IconButton(
            tooltip: '导出 JSON',
            icon: const Icon(Icons.file_download_outlined),
            onPressed: () => _exportJson(context, ref),
          ),
          IconButton(
            tooltip: '附件库',
            icon: const Icon(Icons.attach_file),
            onPressed: () => context.push('/attachments'),
          ),
          const SizedBox(width: 4),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => context.push('/records/new'),
        icon: const Icon(Icons.add),
        label: const Text('新增记录'),
      ),
      body: const _RecordsBody(),
    );
  }
}

// --- AppBar 动作 ---

Future<void> _rebuildIndex(BuildContext context, WidgetRef ref) async {
  final messenger = ScaffoldMessenger.of(context);
  await ref.read(recordsProvider.notifier).rebuildIndex();
  messenger.showSnackBar(const SnackBar(content: Text('索引已重建')));
}

Future<void> _importJson(BuildContext context, WidgetRef ref) async {
  final messenger = ScaffoldMessenger.of(context);
  try {
    final result = await FilePicker.pickFiles(
      type: FileType.custom,
      allowedExtensions: const ['json'],
    );
    if (result.isEmpty) return;
    final file = result.first;
    if (file.path == null) {
      messenger.showSnackBar(const SnackBar(content: Text('无法读取所选文件')));
      return;
    }
    final bytes = await File(file.path!).readAsBytes();
    final decoded = jsonDecode(utf8.decode(bytes));
    final records = <ProfileRecord>[];
    if (decoded is List) {
      for (final item in decoded) {
        if (item is Map) {
          records.add(ProfileRecord.fromJson(item.cast<String, dynamic>()));
        }
      }
    } else if (decoded is Map && decoded['records'] is List) {
      for (final item in decoded['records'] as List) {
        if (item is Map) {
          records.add(ProfileRecord.fromJson(item.cast<String, dynamic>()));
        }
      }
    }
    if (records.isEmpty) {
      messenger.showSnackBar(const SnackBar(content: Text('未解析到任何记录')));
      return;
    }
    await ref.read(recordsProvider.notifier).importAll(records);
    messenger.showSnackBar(SnackBar(content: Text('已导入 ${records.length} 条记录')));
  } catch (e) {
    messenger.showSnackBar(SnackBar(content: Text('导入失败：$e')));
  }
}

Future<void> _exportJson(BuildContext context, WidgetRef ref) async {
  final messenger = ScaffoldMessenger.of(context);
  final records = ref.read(recordsProvider).value ?? const <ProfileRecord>[];
  if (records.isEmpty) {
    messenger.showSnackBar(const SnackBar(content: Text('没有可导出的记录')));
    return;
  }
  final bytes = Uint8List.fromList(
    utf8.encode(
      const JsonEncoder.withIndent('  ')
          .convert(records.map((r) => r.toJson()).toList()),
    ),
  );
  try {
    final uri = await FilePicker.saveFile(
      dialogTitle: '导出记录',
      fileName: 'lifeline-records-${DateTime.now().millisecondsSinceEpoch}.json',
      bytes: bytes,
      mimeType: 'application/json',
    );
    if (uri == null) return;
    messenger.showSnackBar(SnackBar(content: Text('已导出到 $uri')));
  } catch (e) {
    messenger.showSnackBar(SnackBar(content: Text('导出失败：$e')));
  }
}

// --- 列表主体（持有搜索/筛选状态） ---

class _RecordsBody extends ConsumerStatefulWidget {
  const _RecordsBody();

  @override
  ConsumerState<_RecordsBody> createState() => _RecordsBodyState();
}

class _RecordsBodyState extends ConsumerState<_RecordsBody> {
  final TextEditingController _searchCtrl = TextEditingController();
  String _query = '';
  RecordCategory? _filter;

  @override
  void dispose() {
    _searchCtrl.dispose();
    super.dispose();
  }

  bool _match(ProfileRecord r, String q) {
    if (q.isEmpty) return true;
    final needle = q.toLowerCase();
    bool hit(String? s) => (s ?? '').toLowerCase().contains(needle);
    return hit(r.title) ||
        hit(r.organization) ||
        hit(r.role) ||
        r.tags.any((t) => t.toLowerCase().contains(needle));
  }

  @override
  Widget build(BuildContext context) {
    final async = ref.watch(recordsProvider);
    return async.when(
      loading: () => const LoadingView(message: '正在载入记录…'),
      error: (e, _) => ErrorView(
        error: e,
        onRetry: () => ref.invalidate(recordsProvider),
      ),
      data: (all) {
        final present = <RecordCategory>{
          for (final r in all) r.category,
        }.toList()
          ..sort((a, b) => a.index.compareTo(b.index));

        final query = _query.trim();
        final filtered = all
            .where((r) =>
                (_filter == null || r.category == _filter) &&
                _match(r, query))
            .toList();

        final grouped = <RecordCategory, List<ProfileRecord>>{};
        for (final r in filtered) {
          grouped.putIfAbsent(r.category, () => []).add(r);
        }
        final cats = grouped.keys.toList()
          ..sort((a, b) => a.index.compareTo(b.index));

        return Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 900),
            child: Column(
              children: [
                _searchBar(),
                if (all.isNotEmpty) _filterChips(present),
                Expanded(
                  child: filtered.isEmpty
                      ? EmptyState(
                          icon: Icons.inbox_outlined,
                          title: all.isEmpty ? '还没有任何记录' : '没有匹配的记录',
                          message: all.isEmpty
                              ? '点击右下角「新增记录」，或用顶部动作导入 JSON。'
                              : '试试更换关键词或分类筛选。',
                          action: all.isEmpty
                              ? FilledButton.icon(
                                  onPressed: () =>
                                      context.push('/records/new'),
                                  icon: const Icon(Icons.add),
                                  label: const Text('新增记录'),
                                )
                              : null,
                        )
                      : ListView(
                          padding: const EdgeInsets.fromLTRB(16, 4, 16, 96),
                          children: [
                            for (final cat in cats) ...[
                              _groupHeader(context, cat, grouped[cat]!.length),
                              for (final r in grouped[cat]!)
                                _RecordTile(
                                  record: r,
                                  onTap: () =>
                                      context.push('/records/${r.id}'),
                                ),
                            ],
                          ],
                        ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _searchBar() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
      child: TextField(
        controller: _searchCtrl,
        onChanged: (v) => setState(() => _query = v),
        decoration: InputDecoration(
          hintText: '搜索标题 / 机构 / 角色 / 标签',
          prefixIcon: const Icon(Icons.search),
          suffixIcon: _query.isEmpty
              ? null
              : IconButton(
                  tooltip: '清除',
                  icon: const Icon(Icons.clear),
                  onPressed: () {
                    _searchCtrl.clear();
                    setState(() => _query = '');
                  },
                ),
        ),
      ),
    );
  }

  Widget _filterChips(List<RecordCategory> present) {
    return SizedBox(
      height: 46,
      child: ListView(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 16),
        children: [
          Padding(
            padding: const EdgeInsets.only(right: 8),
            child: ChoiceChip(
              label: const Text('全部'),
              selected: _filter == null,
              onSelected: (_) => setState(() => _filter = null),
            ),
          ),
          for (final c in present)
            Padding(
              padding: const EdgeInsets.only(right: 8),
              child: ChoiceChip(
                avatar: Icon(categoryIcon(c), size: 16),
                label: Text(c.labelZh),
                selected: _filter == c,
                onSelected: (_) => setState(() => _filter = c),
              ),
            ),
        ],
      ),
    );
  }

  Widget _groupHeader(BuildContext context, RecordCategory cat, int count) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.fromLTRB(4, 16, 4, 6),
      child: Row(
        children: [
          Icon(categoryIcon(cat), size: 18, color: theme.colorScheme.primary),
          const SizedBox(width: 8),
          Text(cat.labelZh, style: theme.textTheme.titleSmall),
          const SizedBox(width: 8),
          Text('$count',
              style: theme.textTheme.labelSmall
                  ?.copyWith(color: theme.colorScheme.onSurfaceVariant)),
        ],
      ),
    );
  }
}

class _RecordTile extends StatelessWidget {
  const _RecordTile({required this.record, required this.onTap});

  final ProfileRecord record;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final date = formatDateRange(record.startDate, record.endDate);
    final subtitle = <String>[
      if ((record.organization ?? '').trim().isNotEmpty)
        record.organization!.trim(),
      if ((record.role ?? '').trim().isNotEmpty) record.role!.trim(),
    ].join(' · ');

    return Card(
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              CircleAvatar(
                radius: 20,
                child: Icon(categoryIcon(record.category), size: 20),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      record.title.isEmpty ? '（无标题）' : record.title,
                      style: theme.textTheme.titleSmall
                          ?.copyWith(fontWeight: FontWeight.w600),
                    ),
                    if (subtitle.isNotEmpty)
                      Padding(
                        padding: const EdgeInsets.only(top: 2),
                        child: Text(subtitle,
                            style: TextStyle(
                                color: theme.colorScheme.onSurfaceVariant)),
                      ),
                    if (date.isNotEmpty)
                      Padding(
                        padding: const EdgeInsets.only(top: 2),
                        child: Text(date,
                            style: theme.textTheme.labelSmall?.copyWith(
                                color: theme.colorScheme.onSurfaceVariant)),
                      ),
                    if (record.tags.isNotEmpty) ...[
                      const SizedBox(height: 6),
                      TagChips(tags: record.tags),
                    ],
                  ],
                ),
              ),
              const Padding(
                padding: EdgeInsets.only(top: 4),
                child: Icon(Icons.chevron_right, size: 20),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
