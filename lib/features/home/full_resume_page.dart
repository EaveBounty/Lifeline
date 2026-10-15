/// 首页：数据库实时编译出的「完整简历」（Flutter 原生渲染）。
library;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/constants.dart';
import '../../core/platform/file_image.dart';
import '../../core/platform/io_platform.dart';
import '../../core/widgets/common.dart';
import '../../data/models/profile_record.dart';
import '../../data/models/resume_doc.dart';
import '../../data/providers.dart';
import '../../services/update/update_providers.dart';
import '../../services/update/update_service.dart';
import '../attachments/attachment_preview.dart';
import '../update/update_dialog.dart';
import 'profile_edit.dart';

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
    final syncRoot = ref.watch(syncRootProvider).path;

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
            tooltip: '照片采集',
            icon: const Icon(Icons.photo_camera_outlined),
            onPressed: () => context.push('/photos'),
          ),
          IconButton(
            tooltip: '简历库',
            icon: const Icon(Icons.folder_special_outlined),
            onPressed: () => context.push('/resumes'),
          ),
          IconButton(
            tooltip: '导出数据',
            icon: const Icon(Icons.upload_file_outlined),
            onPressed: () => context.push('/export-data'),
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
          return _ResumeView(doc: doc, syncRoot: syncRoot);
        },
      ),
    );
  }
}

class _ResumeView extends ConsumerWidget {
  const _ResumeView({required this.doc, this.syncRoot});
  final ResumeDocument doc;
  final String? syncRoot;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final records = ref.watch(recordsProvider).value ?? const <ProfileRecord>[];
    final profile = ref.watch(profileProvider).value;
    // 素材比档案更新 → 提示简介/亮点可能过时。
    final latestRecord = records.fold<DateTime?>(
      null,
      (a, r) => a == null || r.updatedAt.isAfter(a) ? r.updatedAt : a,
    );
    final stale = profile != null &&
        latestRecord != null &&
        latestRecord.isAfter(profile.updatedAt);

    return Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 900),
        child: ListView(
          padding: const EdgeInsets.fromLTRB(20, 16, 20, 96),
          children: [
            _Header(doc: doc, syncRoot: syncRoot),
            if (stale) ...[
              const SizedBox(height: 10),
              _StaleBanner(onRegen: () => regenerateSummary(context, ref)),
            ],
            const SizedBox(height: 16),
            SectionCard(
              title: '个人简介',
              icon: Icons.notes,
              trailing: _editTrailing(
                onEdit: () => editSummary(context, ref),
                onRegen: () => regenerateSummary(context, ref),
              ),
              child: (doc.summary ?? '').trim().isEmpty
                  ? _placeholder(context, '点右上角「编辑」写个人简介，或点刷新据素材生成')
                  : Text(doc.summary!, style: const TextStyle(height: 1.6)),
            ),
            const SizedBox(height: 12),
            SectionCard(
              title: '核心亮点',
              icon: Icons.star_outline,
              trailing: _editTrailing(
                onEdit: () => editStrengths(context, ref),
                onRegen: () => regenerateSummary(context, ref),
              ),
              child: doc.strengths.isEmpty
                  ? _placeholder(context, '点「编辑」添加亮点（每行一条），或点刷新据素材生成')
                  : Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        for (final s in doc.strengths)
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
                                    child: Text(s,
                                        style: const TextStyle(height: 1.5))),
                              ],
                            ),
                          ),
                      ],
                    ),
            ),
            for (final section in doc.sections)
              if (section.items.isNotEmpty) ...[
                const SizedBox(height: 12),
                _SectionBlock(section: section),
              ],
            const SizedBox(height: 24),
            Center(
              child: Text(
                '由 Lifeline 于 ${_fmt(doc.generatedAt)} 自动编译'
                '${theme.brightness == Brightness.dark ? '' : ''}',
                style: TextStyle(
                  color: theme.colorScheme.outline,
                  fontSize: 12,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  static Widget _placeholder(BuildContext context, String text) => Text(
        text,
        style: TextStyle(
          color: Theme.of(context).colorScheme.onSurfaceVariant,
          fontStyle: FontStyle.italic,
        ),
      );

  static Widget _editTrailing({
    required VoidCallback onEdit,
    required VoidCallback onRegen,
  }) =>
      Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          IconButton(
            tooltip: '据全部素材重新生成',
            visualDensity: VisualDensity.compact,
            icon: const Icon(Icons.auto_awesome, size: 18),
            onPressed: onRegen,
          ),
          IconButton(
            tooltip: '编辑',
            visualDensity: VisualDensity.compact,
            icon: const Icon(Icons.edit_outlined, size: 18),
            onPressed: onEdit,
          ),
        ],
      );

  static String _fmt(DateTime t) =>
      '${t.year}-${t.month.toString().padLeft(2, '0')}-${t.day.toString().padLeft(2, '0')} '
      '${t.hour.toString().padLeft(2, '0')}:${t.minute.toString().padLeft(2, '0')}';
}

class _StaleBanner extends StatelessWidget {
  const _StaleBanner({required this.onRegen});
  final VoidCallback onRegen;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Card(
      color: scheme.tertiaryContainer,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(14, 10, 8, 10),
        child: Row(
          children: [
            Icon(Icons.info_outline, size: 18, color: scheme.onTertiaryContainer),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                '素材有更新，简介与亮点可能已过时。',
                style: TextStyle(color: scheme.onTertiaryContainer),
              ),
            ),
            TextButton(
              onPressed: onRegen,
              child: const Text('一键更新'),
            ),
          ],
        ),
      ),
    );
  }
}

class _Header extends ConsumerWidget {
  const _Header({required this.doc, this.syncRoot});
  final ResumeDocument doc;
  final String? syncRoot;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final h = doc.header;
    final photoPath = (h.photoPath ?? '').trim();
    final photoFile = (syncRoot != null && photoPath.isNotEmpty)
        ? attachmentFileOf(syncRoot!, photoPath)
        : null;
    return Card(
      child: InkWell(
        onTap: () => editProfileBasics(context, ref),
        borderRadius: BorderRadius.circular(12),
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
                        Row(
                          children: [
                            Flexible(
                              child: Text(
                                h.name.isEmpty ? '（点此填写姓名）' : h.name,
                                style: theme.textTheme.headlineMedium?.copyWith(
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ),
                            const SizedBox(width: 6),
                            Icon(Icons.edit, size: 16, color: theme.colorScheme.outline),
                          ],
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
                  const SizedBox(width: 12),
                  _PhotoBox(photoFile: photoFile),
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
                                  size: 5, color: theme.colorScheme.primary),
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
      ),
    );
  }
}

class _PhotoBox extends StatelessWidget {
  const _PhotoBox({required this.photoFile});
  final File? photoFile;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return InkWell(
      onTap: () => context.push('/photos'),
      borderRadius: BorderRadius.circular(8),
      child: Tooltip(
        message: '点击管理照片',
        child: photoFile != null
            ? ClipRRect(
                borderRadius: BorderRadius.circular(8),
                child: SizedBox(
                  width: 84,
                  height: 112,
                  child: fileImage(photoFile!, fit: BoxFit.cover),
                ),
              )
            : Container(
                width: 84,
                height: 112,
                decoration: BoxDecoration(
                  color: theme.colorScheme.surfaceContainerHighest,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(Icons.add_a_photo_outlined,
                        color: theme.colorScheme.onSurfaceVariant),
                    const SizedBox(height: 4),
                    Text('添加照片',
                        style: TextStyle(
                            fontSize: 11,
                            color: theme.colorScheme.onSurfaceVariant)),
                  ],
                ),
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
    final meta = (item.meta ?? '').trim();
    return InkWell(
      onTap: tappable ? () => context.push('/records/$recordId') : null,
      borderRadius: BorderRadius.circular(8),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 4),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // 标题独占一行（窄屏也不会被 meta 挤成竖排）；
            // meta 另起一行、小字、可换行。
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: Text(item.title,
                      style: theme.textTheme.titleSmall
                          ?.copyWith(fontWeight: FontWeight.w600)),
                ),
                if (tappable) ...[
                  const SizedBox(width: 2),
                  Icon(Icons.chevron_right,
                      size: 18, color: theme.colorScheme.outline),
                ],
              ],
            ),
            if (meta.isNotEmpty)
              Padding(
                padding: const EdgeInsets.only(top: 2),
                child: Text(meta,
                    style: TextStyle(
                        color: theme.colorScheme.onSurfaceVariant,
                        fontSize: 12)),
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
