/// 分类管理页：用户可新增 / 重命名 / 换图标 / 排序 / 删除分类（开放分类）。
///
/// 删除或改 slug 时，可选把该分类下的记录迁移到目标分类，绝不丢数据。
library;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/widgets/common.dart';
import '../../data/models/profile_record.dart';
import '../../data/models/record_category.dart';
import '../../data/providers.dart';

/// 「删除分类」对话框中选择「不迁移、保留为未分类」的哨兵值。
const String _kKeepOrphans = '__keep__';

class CategoriesPage extends ConsumerWidget {
  const CategoriesPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final categories = ref.watch(categoriesProvider);
    final records = ref.watch(recordsProvider).value ?? const <ProfileRecord>[];

    final counts = <String, int>{};
    for (final r in records) {
      counts[r.categorySlug] = (counts[r.categorySlug] ?? 0) + 1;
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text('管理分类'),
        actions: [
          Padding(
            padding: const EdgeInsets.only(right: 8),
            child: FilledButton.tonalIcon(
              onPressed: () => _showEditDialog(context, ref, null, categories),
              icon: const Icon(Icons.add),
              label: const Text('新增'),
            ),
          ),
        ],
      ),
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 820),
          child: Column(
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
                child: Text(
                  '拖动右侧把手可调整分类在列表与简历中的顺序。'
                  '删除分类前可把其中的记录迁移到其它分类。',
                  style: TextStyle(
                      color: Theme.of(context).colorScheme.onSurfaceVariant,
                      height: 1.4),
                ),
              ),
              Expanded(
                child: ReorderableListView.builder(
                  padding: const EdgeInsets.fromLTRB(12, 4, 12, 32),
                  itemCount: categories.length,
                  onReorderItem: (oldIndex, newIndex) {
                    final list = [...categories];
                    final item = list.removeAt(oldIndex);
                    list.insert(newIndex, item);
                    ref.read(settingsProvider.notifier).reorderCategories(list);
                  },
                  itemBuilder: (context, index) {
                    final c = categories[index];
                    return Card(
                      key: ValueKey(c.slug),
                      child: ListTile(
                        leading: Icon(categoryIcon(c.icon)),
                        title: Text(c.label),
                        subtitle: Text(
                          '${c.slug} · ${counts[c.slug] ?? 0} 条记录',
                        ),
                        trailing: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            IconButton(
                              tooltip: '编辑',
                              icon: const Icon(Icons.edit_outlined),
                              onPressed: () => _showEditDialog(
                                  context, ref, c, categories),
                            ),
                            IconButton(
                              tooltip: '删除',
                              icon: const Icon(Icons.delete_outline),
                              onPressed: categories.length <= 1
                                  ? null
                                  : () => _confirmDelete(
                                      context, ref, c, categories, counts),
                            ),
                            ReorderableDragStartListener(
                              index: index,
                              child: const Padding(
                                padding: EdgeInsets.symmetric(horizontal: 8),
                                child: Icon(Icons.drag_handle),
                              ),
                            ),
                          ],
                        ),
                      ),
                    );
                  },
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _showEditDialog(
    BuildContext context,
    WidgetRef ref,
    CategoryDef? existing,
    List<CategoryDef> categories,
  ) async {
    final result = await showDialog<CategoryDef>(
      context: context,
      builder: (_) => _CategoryEditDialog(
        existing: existing,
        takenSlugs: {
          for (final c in categories)
            if (c.slug != existing?.slug) c.slug,
        },
      ),
    );
    if (result == null || !context.mounted) return;
    final ctrl = ref.read(settingsProvider.notifier);
    final originalSlug = existing?.slug;
    if (originalSlug != null && originalSlug != result.slug) {
      final moved = await ref
          .read(recordsProvider.notifier)
          .moveCategory(originalSlug, result.slug);
      await ctrl.removeCategory(originalSlug);
      await ctrl.addCategory(result);
      if (context.mounted && moved > 0) {
        _snack(context, '已把 $moved 条记录迁移到「${result.label}」');
      }
    } else if (originalSlug == null) {
      await ctrl.addCategory(result);
    } else {
      await ctrl.updateCategory(result);
    }
  }

  Future<void> _confirmDelete(
    BuildContext context,
    WidgetRef ref,
    CategoryDef def,
    List<CategoryDef> categories,
    Map<String, int> counts,
  ) async {
    final count = counts[def.slug] ?? 0;
    final others = categories.where((c) => c.slug != def.slug).toList();

    if (count == 0) {
      final ok = await _confirm(context, '删除分类',
          '确定删除分类「${def.label}」吗？该分类下暂无记录。');
      if (ok != true || !context.mounted) return;
      await ref.read(settingsProvider.notifier).removeCategory(def.slug);
      return;
    }

    final choice = await showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text('删除分类「${def.label}」'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('该分类下有 $count 条记录。请选择如何处理：'),
            const SizedBox(height: 8),
            for (final c in others)
              ListTile(
                dense: true,
                contentPadding: EdgeInsets.zero,
                leading: Icon(categoryIcon(c.icon), size: 20),
                title: Text('迁移到「${c.label}」'),
                trailing: const Icon(Icons.chevron_right, size: 18),
                onTap: () => Navigator.pop(ctx, c.slug),
              ),
            ListTile(
              dense: true,
              contentPadding: EdgeInsets.zero,
              leading: const Icon(Icons.help_outline, size: 20),
              title: Text('保留为未分类（记录不删除，仍显示旧分类 "${_slugLabel(def)}"）'),
              trailing: const Icon(Icons.chevron_right, size: 18),
              onTap: () => Navigator.pop(ctx, _kKeepOrphans),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('取消'),
          ),
        ],
      ),
    );
    if (choice == null || !context.mounted) return;
    if (choice != _kKeepOrphans) {
      final moved = await ref
          .read(recordsProvider.notifier)
          .moveCategory(def.slug, choice);
      if (context.mounted) _snack(context, '已迁移 $moved 条记录');
    }
    await ref.read(settingsProvider.notifier).removeCategory(def.slug);
  }

  static String _slugLabel(CategoryDef def) =>
      def.label == def.slug ? def.slug : '${def.label}(${def.slug})';

  Future<bool?> _confirm(BuildContext context, String title, String body) =>
      showDialog<bool>(
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

  void _snack(BuildContext context, String message) {
    ScaffoldMessenger.of(context)
        .showSnackBar(SnackBar(content: Text(message)));
  }
}

/// 新增 / 编辑分类对话框。
class _CategoryEditDialog extends StatefulWidget {
  const _CategoryEditDialog({this.existing, required this.takenSlugs});

  final CategoryDef? existing;
  final Set<String> takenSlugs;

  @override
  State<_CategoryEditDialog> createState() => _CategoryEditDialogState();
}

class _CategoryEditDialogState extends State<_CategoryEditDialog> {
  late final TextEditingController _labelCtrl;
  late final TextEditingController _slugCtrl;
  late String _icon;
  bool _slugTouched = false;

  @override
  void initState() {
    super.initState();
    final e = widget.existing;
    _labelCtrl = TextEditingController(text: e?.label ?? '');
    _slugCtrl = TextEditingController(text: e?.slug ?? '');
    _icon = e?.icon ?? 'category';
    _slugTouched = e != null;
    _labelCtrl.addListener(_maybeSyncSlug);
  }

  void _maybeSyncSlug() {
    if (_slugTouched) return;
    setState(() {
      _slugCtrl.text = slugify(_labelCtrl.text);
    });
  }

  @override
  void dispose() {
    _labelCtrl.removeListener(_maybeSyncSlug);
    _labelCtrl.dispose();
    _slugCtrl.dispose();
    super.dispose();
  }

  String? get _slugError {
    final slug = sanitizeSlug(_slugCtrl.text);
    if (_slugCtrl.text.trim().isEmpty) return '请填写标识 slug';
    if (widget.takenSlugs.contains(slug)) return '该 slug 已被占用';
    return null;
  }

  void _submit() {
    final label = _labelCtrl.text.trim();
    if (label.isEmpty) return;
    if (_slugError != null) return;
    final slug = sanitizeSlug(_slugCtrl.text);
    final existing = widget.existing;
    Navigator.pop(
      context,
      CategoryDef(
        slug: slug,
        label: label,
        icon: _icon,
        order: existing?.order ?? 0,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isNew = widget.existing == null;
    return AlertDialog(
      title: Text(isNew ? '新增分类' : '编辑分类'),
      content: SizedBox(
        width: 420,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              TextField(
                controller: _labelCtrl,
                autofocus: true,
                decoration: const InputDecoration(
                  labelText: '名称 *',
                  hintText: '如：志愿服务、开源贡献',
                ),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: _slugCtrl,
                onChanged: (_) => setState(() => _slugTouched = true),
                decoration: InputDecoration(
                  labelText: '标识 slug（目录名 / JSON 值）',
                  errorText: _slugError,
                  helperText: isNew
                      ? '留空将按名称自动生成'
                      : '修改后会迁移旧记录到新标识',
                ),
              ),
              const SizedBox(height: 16),
              Text('图标', style: Theme.of(context).textTheme.labelLarge),
              const SizedBox(height: 8),
              Wrap(
                spacing: 6,
                runSpacing: 6,
                children: [
                  for (final key in categoryIconKeys)
                    InkWell(
                      borderRadius: BorderRadius.circular(8),
                      onTap: () => setState(() => _icon = key),
                      child: Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(8),
                          color: _icon == key
                              ? Theme.of(context).colorScheme.primaryContainer
                              : Theme.of(context)
                                  .colorScheme
                                  .surfaceContainerHighest,
                        ),
                        child: Icon(categoryIcon(key), size: 20),
                      ),
                    ),
                ],
              ),
            ],
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('取消'),
        ),
        FilledButton(
          onPressed: _submit,
          child: const Text('保存'),
        ),
      ],
    );
  }
}
