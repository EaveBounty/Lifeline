/// 附件库：网格图库，支持按记录过滤、预览与删除。
library;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/widgets/common.dart';
import '../../data/models/attachment.dart';
import '../../data/providers.dart';
import 'attachment_preview.dart';

class AttachmentsPage extends ConsumerWidget {
  const AttachmentsPage({super.key, this.recordId});

  /// 可选：仅显示某条记录的附件。
  final String? recordId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final async = ref.watch(attachmentsProvider);
    final root = ref.watch(syncRootProvider).path;

    return Scaffold(
      appBar: AppBar(
        title: Text(recordId == null ? '附件库' : '记录附件'),
      ),
      body: async.when(
        loading: () => const LoadingView(message: '正在载入附件…'),
        error: (e, _) => ErrorView(
          error: e,
          onRetry: () => ref.invalidate(attachmentsProvider),
        ),
        data: (all) {
          final list = recordId == null
              ? all
              : all.where((a) => a.recordId == recordId).toList();
          if (list.isEmpty) {
            return const EmptyState(
              icon: Icons.photo_library_outlined,
              title: '还没有附件',
              message: '在记录编辑页添加图片或文件后，会出现在这里。',
            );
          }
          if (root == null) {
            return const EmptyState(
              icon: Icons.folder_off_outlined,
              title: '尚未设置同步根',
              message: '无法解析附件路径。',
            );
          }
          return LayoutBuilder(
            builder: (context, constraints) {
              final width = constraints.maxWidth;
              final crossAxisCount = width >= 1200
                  ? 5
                  : width >= 900
                      ? 4
                      : width >= 600
                          ? 3
                          : 2;
              return GridView.builder(
                padding: const EdgeInsets.fromLTRB(16, 16, 16, 32),
                gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: crossAxisCount,
                  crossAxisSpacing: 12,
                  mainAxisSpacing: 12,
                  childAspectRatio: 0.82,
                ),
                itemCount: list.length,
                itemBuilder: (context, index) => _AttachmentCard(
                  attachment: list[index],
                  syncRoot: root,
                  onDelete: () => _confirmDelete(context, ref, list[index]),
                ),
              );
            },
          );
        },
      ),
    );
  }

  Future<void> _confirmDelete(
    BuildContext context,
    WidgetRef ref,
    Attachment attachment,
  ) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('删除附件'),
        content: Text('确定删除「${attachment.filename}」吗？文件将同时被移除。'),
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
    await ref.read(attachmentsProvider.notifier).delete(attachment.id);
  }
}

class _AttachmentCard extends StatelessWidget {
  const _AttachmentCard({
    required this.attachment,
    required this.syncRoot,
    required this.onDelete,
  });

  final Attachment attachment;
  final String syncRoot;
  final VoidCallback onDelete;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final file = attachmentFileOf(syncRoot, attachment.relPath);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Expanded(
          child: Stack(
            children: [
              Positioned.fill(
                child: AttachmentThumb(
                  file: file,
                  relPath: attachment.relPath,
                  size: double.infinity,
                  onTap: () => showAttachmentPreview(
                    context,
                    file: file,
                    relPath: attachment.relPath,
                  ),
                ),
              ),
              Positioned(
                top: 2,
                right: 2,
                child: Material(
                  color: theme.colorScheme.surface.withValues(alpha: 0.7),
                  shape: const CircleBorder(),
                  child: IconButton(
                    tooltip: '删除',
                    iconSize: 18,
                    visualDensity: VisualDensity.compact,
                    icon: const Icon(Icons.delete_outline),
                    onPressed: onDelete,
                  ),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 4),
        Text(
          attachment.caption?.trim().isNotEmpty == true
              ? attachment.caption!
              : attachment.filename,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: theme.textTheme.bodySmall,
        ),
      ],
    );
  }
}
