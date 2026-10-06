/// 记录编辑页：新增 / 编辑统一表单，含动态亮点、字段、链接与附件选择。
library;

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:image_picker/image_picker.dart';
import 'package:uuid/uuid.dart';

import '../../core/platform/io_platform.dart';
import '../../core/widgets/common.dart';
import '../../data/models/attachment.dart';
import '../../data/models/profile_record.dart';
import '../../data/models/record_category.dart';
import '../../data/providers.dart';
import '../attachments/attachment_preview.dart';

class RecordEditPage extends ConsumerStatefulWidget {
  const RecordEditPage({super.key, this.recordId, this.initialCategory});

  final String? recordId;
  final String? initialCategory;

  @override
  ConsumerState<RecordEditPage> createState() => _RecordEditPageState();
}

/// 自定义字段的键值编辑行。
class _KvRow {
  _KvRow([String key = '', String value = ''])
      : keyCtrl = TextEditingController(text: key),
        valueCtrl = TextEditingController(text: value);

  final TextEditingController keyCtrl;
  final TextEditingController valueCtrl;

  void dispose() {
    keyCtrl.dispose();
    valueCtrl.dispose();
  }
}

/// 链接的 label + url 编辑行。
class _LinkRow {
  _LinkRow([String label = '', String url = ''])
      : labelCtrl = TextEditingController(text: label),
        urlCtrl = TextEditingController(text: url);

  final TextEditingController labelCtrl;
  final TextEditingController urlCtrl;

  void dispose() {
    labelCtrl.dispose();
    urlCtrl.dispose();
  }
}

class _RecordEditPageState extends ConsumerState<RecordEditPage> {
  final GlobalKey<FormState> _formKey = GlobalKey<FormState>();

  final TextEditingController _title = TextEditingController();
  final TextEditingController _organization = TextEditingController();
  final TextEditingController _role = TextEditingController();
  final TextEditingController _location = TextEditingController();
  final TextEditingController _startDate = TextEditingController();
  final TextEditingController _endDate = TextEditingController();
  final TextEditingController _description = TextEditingController();
  final TextEditingController _tagCtrl = TextEditingController();

  String? _category;
  final List<TextEditingController> _highlights = [];
  final List<String> _tags = [];
  final List<_KvRow> _fields = [];
  final List<_LinkRow> _links = [];
  final List<String> _pendingFiles = [];
  List<String> _existingAttachments = const [];

  ProfileRecord? _origin;
  bool _loaded = false;
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    _category = widget.initialCategory;
    if (widget.recordId == null) {
      _highlights.add(TextEditingController());
    }
  }

  @override
  void dispose() {
    _title.dispose();
    _organization.dispose();
    _role.dispose();
    _location.dispose();
    _startDate.dispose();
    _endDate.dispose();
    _description.dispose();
    _tagCtrl.dispose();
    for (final h in _highlights) {
      h.dispose();
    }
    for (final f in _fields) {
      f.dispose();
    }
    for (final l in _links) {
      l.dispose();
    }
    super.dispose();
  }

  bool get _isNew => widget.recordId == null;

  void _loadOrigin(List<ProfileRecord> list) {
    final id = widget.recordId!;
    for (final r in list) {
      if (r.id == id) {
        _apply(r);
        _origin = r;
        break;
      }
    }
    _loaded = true;
  }

  void _apply(ProfileRecord r) {
    _category = r.categorySlug;
    _title.text = r.title;
    _organization.text = r.organization ?? '';
    _role.text = r.role ?? '';
    _location.text = r.location ?? '';
    _startDate.text = r.startDate ?? '';
    _endDate.text = r.endDate ?? '';
    _description.text = r.description;
    _highlights
      ..clear()
      ..addAll(r.highlights.map((h) => TextEditingController(text: h)));
    if (_highlights.isEmpty) _highlights.add(TextEditingController());
    _tags
      ..clear()
      ..addAll(r.tags);
    _fields
      ..clear()
      ..addAll(r.fields.entries.map((e) => _KvRow(e.key, '${e.value}')));
    _links
      ..clear()
      ..addAll(r.links.map((l) => _LinkRow(l.label, l.url)));
    _existingAttachments = List.of(r.attachments);
  }

  @override
  Widget build(BuildContext context) {
    final async = ref.watch(recordsProvider);
    if (!_isNew && !_loaded) {
      final list = async.value;
      if (list == null) {
        return Scaffold(
          appBar: AppBar(title: const Text('编辑记录')),
          body: const LoadingView(message: '正在载入记录…'),
        );
      }
      _loadOrigin(list);
    }

    return Scaffold(
      appBar: AppBar(
        title: Text(_isNew ? '新增记录' : '编辑记录'),
        actions: [
          TextButton(
            onPressed: _saving ? null : _save,
            child: const Text('保存'),
          ),
          const SizedBox(width: 8),
        ],
      ),
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 820),
          child: Form(
            key: _formKey,
            child: ListView(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 40),
              children: [
                _basicSection(),
                const SizedBox(height: 12),
                _detailSection(),
                const SizedBox(height: 12),
                _tagsSection(),
                const SizedBox(height: 12),
                _fieldsSection(),
                const SizedBox(height: 12),
                _linksSection(),
                const SizedBox(height: 12),
                _attachmentsSection(),
                const SizedBox(height: 24),
                FilledButton.icon(
                  onPressed: _saving ? null : _save,
                  icon: _saving
                      ? const SizedBox(
                          width: 16,
                          height: 16,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Icon(Icons.check),
                  label: const Text('保存'),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  // --- 各分区 ---

  Widget _basicSection() {
    final categories = ref.watch(categoriesProvider);
    final fallbackSlug =
        categories.isNotEmpty ? categories.first.slug : kFallbackCategorySlug;
    final effective = _category ?? fallbackSlug;
    final items = <CategoryDef>[
      ...categories,
      if (!categories.any((c) => c.slug == effective))
        CategoryDef(slug: effective, label: effective),
    ];
    return SectionCard(
      title: '基本信息',
      icon: Icons.badge_outlined,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Expanded(
                child: DropdownButtonFormField<String>(
                  initialValue: effective,
                  isExpanded: true,
                  decoration: const InputDecoration(labelText: '分类'),
                  items: [
                    for (final c in items)
                      DropdownMenuItem(
                        value: c.slug,
                        child: Row(
                          children: [
                            Icon(categoryIcon(c.icon), size: 18),
                            const SizedBox(width: 8),
                            Flexible(
                                child: Text(c.label,
                                    overflow: TextOverflow.ellipsis)),
                          ],
                        ),
                      ),
                  ],
                  onChanged: (v) {
                    if (v != null) setState(() => _category = v);
                  },
                ),
              ),
              IconButton(
                tooltip: '管理分类',
                icon: const Icon(Icons.tune),
                onPressed: () =>
                    context.push('/settings/categories'),
              ),
            ],
          ),
          const SizedBox(height: 12),
          TextFormField(
            controller: _title,
            decoration: const InputDecoration(labelText: '标题 *'),
            validator: (v) =>
                (v ?? '').trim().isEmpty ? '请填写标题' : null,
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _organization,
            decoration: const InputDecoration(labelText: '机构 / 单位'),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _role,
            decoration: const InputDecoration(labelText: '角色 / 职位'),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _location,
            decoration: const InputDecoration(labelText: '地点'),
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: TextField(
                  controller: _startDate,
                  decoration:
                      const InputDecoration(labelText: '开始（YYYY-MM）'),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: TextField(
                  controller: _endDate,
                  decoration: const InputDecoration(
                    labelText: '结束（YYYY-MM）',
                    hintText: '留空 = 至今',
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _detailSection() {
    return SectionCard(
      title: '描述与亮点',
      icon: Icons.notes,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          TextField(
            controller: _description,
            minLines: 3,
            maxLines: 8,
            decoration: const InputDecoration(
              labelText: '描述',
              alignLabelWithHint: true,
            ),
          ),
          const SizedBox(height: 16),
          Text('亮点', style: Theme.of(context).textTheme.labelLarge),
          const SizedBox(height: 8),
          for (var i = 0; i < _highlights.length; i++)
            Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: _highlights[i],
                      decoration: InputDecoration(hintText: '亮点 ${i + 1}'),
                    ),
                  ),
                  IconButton(
                    tooltip: '删除',
                    onPressed: _highlights.length == 1
                        ? null
                        : () => setState(() {
                              _highlights.removeAt(i).dispose();
                            }),
                    icon: const Icon(Icons.remove_circle_outline),
                  ),
                ],
              ),
            ),
          Align(
            alignment: Alignment.centerLeft,
            child: TextButton.icon(
              onPressed: () => setState(() {
                _highlights.add(TextEditingController());
              }),
              icon: const Icon(Icons.add),
              label: const Text('添加亮点'),
            ),
          ),
        ],
      ),
    );
  }

  Widget _tagsSection() {
    return SectionCard(
      title: '标签',
      icon: Icons.sell_outlined,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: TextField(
                  controller: _tagCtrl,
                  decoration: const InputDecoration(
                    hintText: '输入标签后回车，支持逗号分隔',
                  ),
                  onSubmitted: _addTags,
                ),
              ),
              IconButton(
                tooltip: '添加标签',
                onPressed: () => _addTags(_tagCtrl.text),
                icon: const Icon(Icons.add),
              ),
            ],
          ),
          if (_tags.isNotEmpty) ...[
            const SizedBox(height: 8),
            Wrap(
              spacing: 6,
              runSpacing: 6,
              children: [
                for (final t in _tags)
                  Chip(
                    label: Text(t, style: const TextStyle(fontSize: 12)),
                    visualDensity: VisualDensity.compact,
                    onDeleted: () => setState(() => _tags.remove(t)),
                  ),
              ],
            ),
          ],
        ],
      ),
    );
  }

  Widget _fieldsSection() {
    return SectionCard(
      title: '自定义字段',
      icon: Icons.list_alt,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          for (var i = 0; i < _fields.length; i++)
            Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: Row(
                children: [
                  Expanded(
                    flex: 2,
                    child: TextField(
                      controller: _fields[i].keyCtrl,
                      decoration: const InputDecoration(labelText: '键'),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    flex: 3,
                    child: TextField(
                      controller: _fields[i].valueCtrl,
                      decoration: const InputDecoration(labelText: '值'),
                    ),
                  ),
                  IconButton(
                    tooltip: '删除',
                    onPressed: () => setState(() {
                      _fields.removeAt(i).dispose();
                    }),
                    icon: const Icon(Icons.remove_circle_outline),
                  ),
                ],
              ),
            ),
          Align(
            alignment: Alignment.centerLeft,
            child: TextButton.icon(
              onPressed: () => setState(() {
                _fields.add(_KvRow());
              }),
              icon: const Icon(Icons.add),
              label: const Text('添加字段'),
            ),
          ),
        ],
      ),
    );
  }

  Widget _linksSection() {
    return SectionCard(
      title: '链接',
      icon: Icons.link,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          for (var i = 0; i < _links.length; i++)
            Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    flex: 2,
                    child: TextField(
                      controller: _links[i].labelCtrl,
                      decoration: const InputDecoration(labelText: '名称'),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    flex: 3,
                    child: TextField(
                      controller: _links[i].urlCtrl,
                      decoration: const InputDecoration(labelText: 'URL'),
                    ),
                  ),
                  IconButton(
                    tooltip: '删除',
                    onPressed: () => setState(() {
                      _links.removeAt(i).dispose();
                    }),
                    icon: const Icon(Icons.remove_circle_outline),
                  ),
                ],
              ),
            ),
          Align(
            alignment: Alignment.centerLeft,
            child: TextButton.icon(
              onPressed: () => setState(() {
                _links.add(_LinkRow());
              }),
              icon: const Icon(Icons.add),
              label: const Text('添加链接'),
            ),
          ),
        ],
      ),
    );
  }

  Widget _attachmentsSection() {
    final scheme = Theme.of(context).colorScheme;
    return SectionCard(
      title: '附件',
      icon: Icons.attach_file,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (_existingAttachments.isEmpty && _pendingFiles.isEmpty)
            Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: Text('暂无附件',
                  style: TextStyle(color: scheme.onSurfaceVariant)),
            ),
          for (final rel in _existingAttachments)
            ListTile(
              dense: true,
              contentPadding: EdgeInsets.zero,
              leading: Icon(isImageAttachment(rel)
                  ? Icons.image_outlined
                  : Icons.insert_drive_file_outlined),
              title: Text(attachmentName(rel)),
              subtitle: Text(rel,
                  maxLines: 1, overflow: TextOverflow.ellipsis),
            ),
          for (final path in _pendingFiles)
            ListTile(
              dense: true,
              contentPadding: EdgeInsets.zero,
              leading: const Icon(Icons.fiber_new_outlined),
              title: Text(attachmentName(path)),
              subtitle: const Text('待导入（保存后写入）'),
              trailing: IconButton(
                tooltip: '移除',
                icon: const Icon(Icons.close),
                onPressed: () => setState(() => _pendingFiles.remove(path)),
              ),
            ),
          const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              OutlinedButton.icon(
                onPressed: _pickImages,
                icon: const Icon(Icons.add_photo_alternate_outlined),
                label: const Text('添加图片'),
              ),
              OutlinedButton.icon(
                onPressed: _pickFiles,
                icon: const Icon(Icons.upload_file_outlined),
                label: const Text('添加文件'),
              ),
            ],
          ),
        ],
      ),
    );
  }

  // --- 动作 ---

  void _addTags(String raw) {
    final parts = raw.split(RegExp(r'[,，]'));
    var changed = false;
    for (final part in parts) {
      final t = part.trim();
      if (t.isEmpty || _tags.contains(t)) continue;
      _tags.add(t);
      changed = true;
    }
    _tagCtrl.clear();
    if (changed) setState(() {});
  }

  Future<void> _pickImages() async {
    final messenger = ScaffoldMessenger.of(context);
    try {
      final paths = <String>[];
      if (Platform.isAndroid || Platform.isIOS) {
        final picked = await ImagePicker().pickMultiImage();
        paths.addAll(picked.map((x) => x.path));
      } else {
        final result = await FilePicker.pickFiles(
          type: FileType.image,
        );
        if (result.isNotEmpty) {
          paths.addAll(result.map((f) => f.path).whereType<String>());
        }
      }
      if (paths.isEmpty || !mounted) return;
      setState(() => _pendingFiles.addAll(paths));
    } catch (e) {
      if (!mounted) return;
      messenger.showSnackBar(SnackBar(content: Text('选择图片失败：$e')));
    }
  }

  Future<void> _pickFiles() async {
    final messenger = ScaffoldMessenger.of(context);
    try {
      final result = await FilePicker.pickFiles();
      final paths =
          result.map((f) => f.path).whereType<String>().toList();
      if (paths.isEmpty || !mounted) return;
      setState(() => _pendingFiles.addAll(paths));
    } catch (e) {
      if (!mounted) return;
      messenger.showSnackBar(SnackBar(content: Text('选择文件失败：$e')));
    }
  }

  Future<void> _save() async {
    if (!(_formKey.currentState?.validate() ?? false)) return;
    FocusScope.of(context).unfocus();
    setState(() => _saving = true);
    final messenger = ScaffoldMessenger.of(context);
    try {
      final now = DateTime.now();
      final id = widget.recordId ?? const Uuid().v4();
      final base = _origin;
      final categories = ref.read(categoriesProvider);
      final fallbackSlug =
          categories.isNotEmpty ? categories.first.slug : kFallbackCategorySlug;
      final record = ProfileRecord(
        id: id,
        categorySlug: _category ?? fallbackSlug,
        title: _title.text.trim(),
        organization: _nullIfEmpty(_organization.text),
        role: _nullIfEmpty(_role.text),
        location: _nullIfEmpty(_location.text),
        startDate: _nullIfEmpty(_startDate.text),
        endDate: _nullIfEmpty(_endDate.text),
        description: _description.text.trim(),
        highlights: _highlights
            .map((c) => c.text.trim())
            .where((s) => s.isNotEmpty)
            .toList(),
        tags: List.of(_tags),
        fields: _collectFields(),
        attachments: List.of(_existingAttachments),
        links: _collectLinks(),
        source: base?.source ?? const RecordSource(type: 'manual'),
        ai: base?.ai ?? const RecordAiMeta(),
        createdAt: base?.createdAt ?? now,
        updatedAt: now,
        status: base?.status ?? 'active',
        order: base?.order ?? 0,
      );

      final notifier = ref.read(recordsProvider.notifier);
      if (base == null) {
        await notifier.add(record);
      } else {
        await notifier.updateRecord(record);
      }

      if (_pendingFiles.isNotEmpty) {
        for (final path in _pendingFiles) {
          await ref
              .read(attachmentsProvider.notifier)
              .importFile(File(path), recordId: id);
        }
        final atts =
            ref.read(attachmentsProvider).value ?? const <Attachment>[];
        final rels = <String>{
          ..._existingAttachments,
          for (final a in atts)
            if (a.recordId == id) a.relPath,
        }.toList();
        await notifier.updateRecord(
          record.copyWith(attachments: rels, updatedAt: DateTime.now()),
        );
      }

      if (!mounted) return;
      context.pop();
    } catch (e) {
      if (!mounted) return;
      setState(() => _saving = false);
      messenger.showSnackBar(SnackBar(content: Text('保存失败：$e')));
    }
  }

  Map<String, dynamic> _collectFields() {
    final map = <String, dynamic>{};
    for (final row in _fields) {
      final k = row.keyCtrl.text.trim();
      if (k.isEmpty) continue;
      map[k] = row.valueCtrl.text.trim();
    }
    return map;
  }

  List<RecordLink> _collectLinks() {
    final out = <RecordLink>[];
    for (final row in _links) {
      final url = row.urlCtrl.text.trim();
      if (url.isEmpty) continue;
      out.add(RecordLink(label: row.labelCtrl.text.trim(), url: url));
    }
    return out;
  }

  String? _nullIfEmpty(String s) {
    final t = s.trim();
    return t.isEmpty ? null : t;
  }
}
