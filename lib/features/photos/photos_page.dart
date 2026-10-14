/// 照片采集：导入证件照/个人照，标注标签并设为档案照片，供智能选图。
library;

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_picker/image_picker.dart';

import '../../core/platform/io_platform.dart';
import '../../core/widgets/common.dart';
import '../../data/models/photo.dart';
import '../../data/providers.dart';
import '../attachments/attachment_preview.dart';

class PhotosPage extends ConsumerWidget {
  const PhotosPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final async = ref.watch(photosProvider);
    final root = ref.watch(syncRootProvider).path;
    final primary = ref.watch(profileProvider).value?.photoPath;

    return Scaffold(
      appBar: AppBar(
        title: const Text('照片采集'),
        actions: [
          IconButton(
            tooltip: '拍照（移动端）',
            icon: const Icon(Icons.photo_camera_outlined),
            onPressed: () => _importCamera(context, ref),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _importFiles(context, ref),
        icon: const Icon(Icons.add_photo_alternate_outlined),
        label: const Text('导入照片'),
      ),
      body: async.when(
        loading: () => const LoadingView(message: '正在载入照片库…'),
        error: (e, _) => ErrorView(
          error: e,
          onRetry: () => ref.invalidate(photosProvider),
        ),
        data: (list) {
          if (root == null) {
            return const EmptyState(
              icon: Icons.folder_off_outlined,
              title: '尚未设置同步根',
              message: '无法存放照片。',
            );
          }
          if (list.isEmpty) {
            return const EmptyState(
              icon: Icons.person_outline,
              title: '还没有照片',
              message: '导入证件照或近照后，生成简历时会按分辨率、时间、标签自动挑选最合适的一张。',
            );
          }
          return ListView(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 96),
            children: [
              SectionCard(
                title: '智能选图规则',
                icon: Icons.auto_awesome,
                child: Text(
                  '正式投递优先用「证件照」；分辨率越高、比例越接近 3:4、时间越新，得分越高；'
                  '标注「正装/白底/蓝底」加分，「生活照/休闲」减分；可选手动指定。',
                  style: TextStyle(
                    color: Theme.of(context).colorScheme.onSurfaceVariant,
                    height: 1.5,
                  ),
                ),
              ),
              const SizedBox(height: 12),
              GridView.builder(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(
                  maxCrossAxisExtent: 240,
                  crossAxisSpacing: 12,
                  mainAxisSpacing: 12,
                  childAspectRatio: 0.72,
                ),
                itemCount: list.length,
                itemBuilder: (_, i) => _PhotoCard(
                  photo: list[i],
                  syncRoot: root,
                  isPrimary: primary == list[i].relPath,
                ),
              ),
            ],
          );
        },
      ),
    );
  }

  Future<void> _importFiles(BuildContext context, WidgetRef ref) async {
    final messenger = ScaffoldMessenger.of(context);
    final files = await FilePicker.pickFiles(type: FileType.image);
    if (files.isEmpty) return;
    var n = 0;
    for (final f in files) {
      final path = f.path;
      if (path == null) continue;
      final photo =
          await ref.read(photosProvider.notifier).importFile(File(path));
      if (photo != null) n++;
    }
    messenger.showSnackBar(SnackBar(content: Text('已导入 $n 张照片')));
  }

  Future<void> _importCamera(BuildContext context, WidgetRef ref) async {
    final messenger = ScaffoldMessenger.of(context);
    try {
      final picked = await ImagePicker()
          .pickImage(source: ImageSource.camera, imageQuality: 95);
      if (picked == null) return;
      final photo =
          await ref.read(photosProvider.notifier).importFile(File(picked.path));
      messenger.showSnackBar(
        SnackBar(content: Text(photo == null ? '拍摄失败' : '已保存照片')),
      );
    } catch (e) {
      messenger.showSnackBar(SnackBar(content: Text('无法调用相机：$e')));
    }
  }
}

class _PhotoCard extends ConsumerWidget {
  const _PhotoCard({
    required this.photo,
    required this.syncRoot,
    required this.isPrimary,
  });

  final Photo photo;
  final String syncRoot;
  final bool isPrimary;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final file = attachmentFileOf(syncRoot, photo.relPath);
    final dims = (photo.width != null && photo.height != null)
        ? '${photo.width}×${photo.height}'
        : '尺寸未知';
    return Card(
      clipBehavior: Clip.antiAlias,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Expanded(
            child: Stack(
              children: [
                Positioned.fill(
                  child: AttachmentThumb(
                    file: file,
                    relPath: photo.relPath,
                    size: double.infinity,
                    onTap: () => showAttachmentPreview(
                      context,
                      file: file,
                      relPath: photo.relPath,
                    ),
                  ),
                ),
                if (isPrimary)
                  Positioned(
                    top: 4,
                    left: 4,
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                      decoration: BoxDecoration(
                        color: theme.colorScheme.primary,
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Text('档案照片',
                          style: TextStyle(
                              color: theme.colorScheme.onPrimary, fontSize: 11)),
                    ),
                  ),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(8, 6, 4, 4),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    if (photo.idPhoto)
                      const Padding(
                        padding: EdgeInsets.only(right: 4),
                        child: Icon(Icons.badge_outlined, size: 14),
                      ),
                    Expanded(
                      child: Text(
                        photo.filename,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: theme.textTheme.bodySmall,
                      ),
                    ),
                  ],
                ),
                Text(dims,
                    style: TextStyle(
                        fontSize: 11, color: theme.colorScheme.onSurfaceVariant)),
                if (photo.tags.isNotEmpty)
                  Wrap(
                    spacing: 4,
                    runSpacing: 0,
                    children: [
                      for (final t in photo.tags.take(3))
                        Chip(
                          label: Text(t, style: const TextStyle(fontSize: 10)),
                          visualDensity: VisualDensity.compact,
                          materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                          padding: EdgeInsets.zero,
                        ),
                    ],
                  ),
              ],
            ),
          ),
          OverflowBar(
            alignment: MainAxisAlignment.end,
            children: [
              IconButton(
                tooltip: photo.idPhoto ? '取消证件照' : '标为证件照',
                visualDensity: VisualDensity.compact,
                icon: Icon(
                  photo.idPhoto ? Icons.badge : Icons.badge_outlined,
                  size: 18,
                ),
                onPressed: () => ref
                    .read(photosProvider.notifier)
                    .updatePhoto(photo.copyWith(idPhoto: !photo.idPhoto)),
              ),
              IconButton(
                tooltip: '编辑标签',
                visualDensity: VisualDensity.compact,
                icon: const Icon(Icons.label_outline, size: 18),
                onPressed: () => _editTags(context, ref),
              ),
              IconButton(
                tooltip: '设为档案照片',
                visualDensity: VisualDensity.compact,
                icon: Icon(
                  isPrimary ? Icons.star : Icons.star_border,
                  size: 18,
                ),
                onPressed: () =>
                    ref.read(photosProvider.notifier).setPrimary(photo.relPath),
              ),
              IconButton(
                tooltip: '删除',
                visualDensity: VisualDensity.compact,
                icon: const Icon(Icons.delete_outline, size: 18),
                onPressed: () => _confirmDelete(context, ref),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Future<void> _editTags(BuildContext context, WidgetRef ref) async {
    final controller = TextEditingController(text: photo.tags.join('，'));
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('编辑标签'),
        content: TextField(
          controller: controller,
          autofocus: true,
          decoration: const InputDecoration(
            hintText: '如：证件照，正装，白底',
            border: OutlineInputBorder(),
            helperText: '用逗号分隔；证件照/正装/白底/蓝底 加分，生活照/休闲 减分',
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
      final tags = controller.text
          .split(RegExp(r'[,，、;；\s]+'))
          .map((e) => e.trim())
          .where((e) => e.isNotEmpty)
          .toList();
      await ref
          .read(photosProvider.notifier)
          .updatePhoto(photo.copyWith(tags: tags));
    }
    controller.dispose();
  }

  Future<void> _confirmDelete(BuildContext context, WidgetRef ref) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('删除照片？'),
        content: Text('将删除「${photo.filename}」，文件同时移除，无法撤销。'),
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
      await ref.read(photosProvider.notifier).delete(photo.id);
    }
  }
}
