/// 首页：数据库实时编译出的「完整简历」（Flutter 原生渲染）。
library;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/constants.dart';
import '../../core/widgets/common.dart';
import '../../data/models/resume_doc.dart';
import '../../data/providers.dart';
import '../../services/update/update_providers.dart';
import '../../services/update/update_service.dart';
import '../update/update_dialog.dart';

class FullResumePage extends ConsumerStatefulWidget {
  const FullResumePage({super.key});

  @override
  ConsumerState<FullResumePage> createState() => _FullResumePageState();
}

class _FullResumePageState extends ConsumerState<FullResumePage> {
  bool _updateChecked = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _maybeCheckUpdate());
  }

  Future<void> _maybeCheckUpdate() async {
    if (_updateChecked) return;
    _updateChecked = true;
    try {
      if (!await UpdatePrefs.autoCheckEnabled()) return;
      final info = await checkForUpdate();
      if (info == null || !mounted) return;
      await showUpdateDialog(context, info);
    } catch (_) {
      // 检查失败静默。
    }
  }

  @override
  Widget build(BuildContext context) {
    final doc = ref.watch(fullResumeProvider);
    final profileAsync = ref.watch(profileProvider);

    return Scaffold(
      appBar: AppBar(
        title: Row(
          children: [
            const Icon(Icons.all_inclusive, size: 22),
            const SizedBox(width: 8),
            const Text(AppInfo.nameZh),
          ],
        ),
        actions: [
          IconButton(
            tooltip: '智能录入',
            icon: const Icon(Icons.auto_awesome),
            onPressed: () => context.push('/capture'),
          ),
          IconButton(
            tooltip: '信息记录',
            icon: const Icon(Icons.list_alt),
            onPressed: () => context.push('/records'),
          ),
          IconButton(
            tooltip: '定向导出',
            icon: const Icon(Icons.ios_share),
            onPressed: () => context.push('/export'),
          ),
          IconButton(
            tooltip: '简历库',
            icon: const Icon(Icons.folder_special_outlined),
            onPressed: () => context.push('/resumes'),
          ),
          IconButton(
            tooltip: '设置',
            icon: const Icon(Icons.settings_outlined),
            onPressed: () => context.push('/settings'),
          ),
          const SizedBox(width: 8),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => context.push('/records/new'),
        icon: const Icon(Icons.add),
        label: const Text('添加信息'),
      ),
      body: profileAsync.when(
        loading: () => const LoadingView(message: '正在载入档案…'),
        error: (e, _) => ErrorView(
          error: e,
          onRetry: () => ref.invalidate(profileProvider),
        ),
        data: (_) {
          if (doc == null) {
            return const LoadingView(message: '正在编译完整简历…');
          }
          final hasContent = doc.sections.any((s) => s.items.isNotEmpty) ||
              (doc.summary?.isNotEmpty ?? false) ||
              doc.header.name.isNotEmpty;
          if (!hasContent) {
            return EmptyState(
              icon: Icons.auto_stories_outlined,
              title: '还没有任何信息',
              message: '添加教育、工作、项目、奖项等信息，或让 AI 从一段文字/一张图片自动录入。'
                  '首页会实时编译成一份完整简历。',
              action: FilledButton.icon(
                onPressed: () => context.push('/capture'),
                icon: const Icon(Icons.auto_awesome),
                label: const Text('智能录入'),
              ),
            );
          }
          return _ResumeView(doc: doc);
        },
      ),
    );
  }
}

class _ResumeView extends StatelessWidget {
  const _ResumeView({required this.doc});
  final ResumeDocument doc;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 900),
        child: ListView(
          padding: const EdgeInsets.fromLTRB(20, 16, 20, 96),
          children: [
            _Header(doc: doc),
            if (doc.summary != null && doc.summary!.trim().isNotEmpty) ...[
              const SizedBox(height: 16),
              SectionCard(
                title: '个人简介',
                icon: Icons.notes,
                child: Text(doc.summary!, style: const TextStyle(height: 1.6)),
              ),
            ],
            if (doc.strengths.isNotEmpty) ...[
              const SizedBox(height: 12),
              SectionCard(
                title: '核心优势',
                icon: Icons.star_outline,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: doc.strengths
                      .map((s) => Padding(
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
                                    child: Text(s,
                                        style: const TextStyle(height: 1.5))),
                              ],
                            ),
                          ))
                      .toList(),
                ),
              ),
            ],
            for (final section in doc.sections)
              if (section.items.isNotEmpty) ...[
                const SizedBox(height: 12),
                _SectionBlock(section: section),
              ],
            const SizedBox(height: 24),
            Center(
              child: Text(
                '由 Lifeline 于 ${_fmt(doc.generatedAt)} 自动编译',
                style: TextStyle(
                  color: Theme.of(context).colorScheme.outline,
                  fontSize: 12,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  static String _fmt(DateTime t) =>
      '${t.year}-${t.month.toString().padLeft(2, '0')}-${t.day.toString().padLeft(2, '0')} '
      '${t.hour.toString().padLeft(2, '0')}:${t.minute.toString().padLeft(2, '0')}';
}

class _Header extends StatelessWidget {
  const _Header({required this.doc});
  final ResumeDocument doc;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final h = doc.header;
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        h.name.isEmpty ? '（未填写姓名）' : h.name,
                        style: theme.textTheme.headlineMedium?.copyWith(
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      if ((h.englishName ?? '').trim().isNotEmpty)
                        Text(h.englishName!,
                            style: theme.textTheme.titleMedium?.copyWith(
                                color: theme.colorScheme.onSurfaceVariant)),
                      if ((h.headline ?? '').trim().isNotEmpty) ...[
                        const SizedBox(height: 6),
                        Text(h.headline!,
                            style: theme.textTheme.titleSmall?.copyWith(
                                color: theme.colorScheme.primary)),
                      ],
                    ],
                  ),
                ),
                if (h.photoPath != null)
                  const Icon(Icons.account_circle, size: 56),
              ],
            ),
            if (h.contacts.isNotEmpty) ...[
              const SizedBox(height: 14),
              Wrap(
                spacing: 16,
                runSpacing: 8,
                children: h.contacts
                    .map((c) => Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(Icons.circle,
                                size: 5,
                                color: theme.colorScheme.primary),
                            const SizedBox(width: 6),
                            Text(c.label,
                                style: TextStyle(
                                    color: theme.colorScheme.onSurfaceVariant)),
                            const SizedBox(width: 4),
                            Text(c.value),
                          ],
                        ))
                    .toList(),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _SectionBlock extends StatelessWidget {
  const _SectionBlock({required this.section});
  final ResumeSection section;

  @override
  Widget build(BuildContext context) {
    return SectionCard(
      title: section.title,
      icon: Icons.segment,
      child: Column(
        children: section.items
            .map((item) => _ItemTile(item: item))
            .toList(),
      ),
    );
  }
}

class _ItemTile extends StatelessWidget {
  const _ItemTile({required this.item});
  final ResumeItem item;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final recordId = item.sourceRecordId;
    final tappable = recordId != null && recordId.isNotEmpty;
    return InkWell(
      onTap: tappable ? () => context.push('/records/$recordId') : null,
      borderRadius: BorderRadius.circular(8),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 4),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: Text(item.title,
                      style: theme.textTheme.titleSmall
                          ?.copyWith(fontWeight: FontWeight.w600)),
                ),
                if ((item.meta ?? '').isNotEmpty)
                  Text(item.meta!,
                      style: TextStyle(
                          color: theme.colorScheme.onSurfaceVariant,
                          fontSize: 12)),
                if (tappable) ...[
                  const SizedBox(width: 2),
                  Icon(Icons.chevron_right,
                      size: 18, color: theme.colorScheme.outline),
                ],
              ],
            ),
            if ((item.subtitle ?? '').isNotEmpty)
              Padding(
                padding: const EdgeInsets.only(top: 2),
                child: Text(item.subtitle!,
                    style: TextStyle(color: theme.colorScheme.primary)),
              ),
            if (item.bullets.isNotEmpty) ...[
              const SizedBox(height: 6),
              ...item.bullets.map((b) => Padding(
                    padding: const EdgeInsets.symmetric(vertical: 2),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Padding(
                          padding: EdgeInsets.only(top: 6),
                          child: Icon(Icons.circle, size: 5),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                            child:
                                Text(b, style: const TextStyle(height: 1.5))),
                      ],
                    ),
                  )),
            ],
            if ((item.description ?? '').trim().isNotEmpty) ...[
              const SizedBox(height: 4),
              Text(item.description!,
                  style: TextStyle(
                      height: 1.5, color: theme.colorScheme.onSurfaceVariant)),
            ],
            if (item.tags.isNotEmpty) ...[
              const SizedBox(height: 6),
              TagChips(tags: item.tags),
            ],
          ],
        ),
      ),
    );
  }
}
