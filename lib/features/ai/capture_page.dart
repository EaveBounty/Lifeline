/// 智能录入：文字/图片 -> AI 结构化草稿 -> 人工确认 -> 落库。
library;

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:image_picker/image_picker.dart';
import 'package:uuid/uuid.dart';

import '../../core/platform/io_platform.dart';
import '../../core/widgets/common.dart';
import '../../data/models/record_category.dart';
import '../../data/providers.dart';
import '../../services/ai/ai_providers.dart';
import '../../services/ai/ai_service.dart';

class CapturePage extends ConsumerStatefulWidget {
  const CapturePage({super.key});

  @override
  ConsumerState<CapturePage> createState() => _CapturePageState();
}

class _CapturePageState extends ConsumerState<CapturePage> {
  final TextEditingController _inputCtrl = TextEditingController();
  final TextEditingController _titleCtrl = TextEditingController();
  final TextEditingController _orgCtrl = TextEditingController();
  final TextEditingController _roleCtrl = TextEditingController();
  final TextEditingController _locCtrl = TextEditingController();
  final TextEditingController _startCtrl = TextEditingController();
  final TextEditingController _endCtrl = TextEditingController();
  final TextEditingController _descCtrl = TextEditingController();

  final List<TextEditingController> _highlightCtrls = [];
  final List<TextEditingController> _tagCtrls = [];
  final List<_FieldRow> _fieldRows = [];

  EntryDraft? _draft;
  String? _category;
  String? _imagePath;
  String? _error;

  bool _analyzing = false;
  bool _saving = false;

  @override
  void dispose() {
    _inputCtrl.dispose();
    _titleCtrl.dispose();
    _orgCtrl.dispose();
    _roleCtrl.dispose();
    _locCtrl.dispose();
    _startCtrl.dispose();
    _endCtrl.dispose();
    _descCtrl.dispose();
    _disposeList(_highlightCtrls);
    _disposeList(_tagCtrls);
    for (final row in _fieldRows) {
      row.dispose();
    }
    super.dispose();
  }

  void _disposeList(List<TextEditingController> list) {
    for (final c in list) {
      c.dispose();
    }
    list.clear();
  }

  Future<void> _pickImage() async {
    String? path;
    try {
      if (Platform.isAndroid || Platform.isIOS) {
        final picked = await ImagePicker()
            .pickImage(source: ImageSource.gallery, imageQuality: 90);
        path = picked?.path;
      } else {
        final result = await FilePicker.pickFiles(
          type: FileType.image,
          dialogTitle: '选择佐证图片',
        );
        path = result.isNotEmpty ? result.first.path : null;
      }
    } catch (e) {
      if (mounted) _showSnack('选择图片失败：$e');
      return;
    }
    if (path != null && mounted) {
      setState(() => _imagePath = path);
    }
  }

  Future<void> _analyze() async {
    final text = _inputCtrl.text.trim();
    if (text.isEmpty && _imagePath == null) {
      _showSnack('请输入文字或选择图片');
      return;
    }
    setState(() {
      _analyzing = true;
      _error = null;
    });

    final service = ref.read(aiServiceProvider);
    final result = await service.analyzeEntry(
      text: text.isEmpty ? null : text,
      imagePath: _imagePath,
    );
    if (!mounted) return;

    setState(() {
      _analyzing = false;
      result.when(
        ok: (draft) {
          _applyDraft(draft);
          _error = null;
        },
        err: (message, _) => _error = message,
      );
    });
  }

  void _applyDraft(EntryDraft draft) {
    _draft = draft;
    _category = draft.category;
    _titleCtrl.text = draft.title;
    _orgCtrl.text = draft.organization ?? '';
    _roleCtrl.text = draft.role ?? '';
    _locCtrl.text = draft.location ?? '';
    _startCtrl.text = draft.startDate ?? '';
    _endCtrl.text = draft.endDate ?? '';
    _descCtrl.text = draft.description;
    _fillList(_highlightCtrls, draft.highlights);
    _fillList(_tagCtrls, draft.tags);
    for (final row in _fieldRows) {
      row.dispose();
    }
    _fieldRows
      ..clear()
      ..addAll(draft.fields.entries.map((e) => _FieldRow(e.key, '${e.value}')));
  }

  void _fillList(List<TextEditingController> list, List<String> values) {
    _disposeList(list);
    for (final v in values) {
      list.add(TextEditingController(text: v));
    }
  }

  void _addTo(List<TextEditingController> list) {
    setState(() => list.add(TextEditingController()));
  }

  void _removeFrom(List<TextEditingController> list, int index) {
    setState(() {
      final c = list.removeAt(index);
      c.dispose();
    });
  }

  Future<void> _save() async {
    final draft = _draft;
    if (draft == null) return;
    setState(() => _saving = true);

    draft.category = _category ?? draft.category;
    draft.title = _titleCtrl.text.trim();
    draft.organization = _emptyToNull(_orgCtrl.text);
    draft.role = _emptyToNull(_roleCtrl.text);
    draft.location = _emptyToNull(_locCtrl.text);
    draft.startDate = _emptyToNull(_startCtrl.text);
    draft.endDate = _emptyToNull(_endCtrl.text);
    draft.description = _descCtrl.text;
    draft.highlights =
        _highlightCtrls.map((c) => c.text.trim()).where((e) => e.isNotEmpty).toList();
    draft.tags =
        _tagCtrls.map((c) => c.text.trim()).where((e) => e.isNotEmpty).toList();
    draft.fields = {
      for (final row in _fieldRows)
        if (row.keyCtrl.text.trim().isNotEmpty)
          row.keyCtrl.text.trim(): row.valueCtrl.text.trim(),
    };

    final id = const Uuid().v4();
    try {
      final record = draft.toRecord(id);
      final notifier = ref.read(recordsProvider.notifier);
      await notifier.add(record);
      // A2：导入的图片必须回写 record.attachments，与记录编辑页行为一致。
      final imagePath = _imagePath;
      if (imagePath != null) {
        final attachment = await ref
            .read(attachmentsProvider.notifier)
            .importFile(
              File(imagePath),
              recordId: id,
              caption: 'AI 录入佐证图片',
            );
        if (attachment != null) {
          await notifier.updateRecord(
            record.copyWith(
              attachments: [...record.attachments, attachment.relPath],
              updatedAt: DateTime.now(),
            ),
          );
        }
      }
    } catch (e) {
      if (mounted) {
        setState(() => _saving = false);
        _showSnack('保存失败：$e');
      }
      return;
    }

    if (!mounted) return;
    _showSnack('已保存');
    context.pop();
  }

  String? _emptyToNull(String value) {
    final v = value.trim();
    return v.isEmpty ? null : v;
  }

  void _showSnack(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context)
        .showSnackBar(SnackBar(content: Text(message)));
  }

  @override
  Widget build(BuildContext context) {
    final hasProvider = ref.watch(
          settingsProvider.select(
            (s) => s.value?.providers.any((p) => p.enabled) ?? false,
          ),
        );

    return Scaffold(
      appBar: AppBar(title: const Text('智能录入')),
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 900),
          child: ListView(
            padding: const EdgeInsets.fromLTRB(20, 16, 20, 40),
            children: [
              if (!hasProvider) _configBanner(),
              _inputCard(),
              if (_error != null) ...[
                const SizedBox(height: 12),
                _errorCard(_error!),
              ],
              if (_draft != null) ...[
                const SizedBox(height: 12),
                _draftCard(),
              ],
            ],
          ),
        ),
      ),
    );
  }

  Widget _configBanner() {
    final scheme = Theme.of(context).colorScheme;
    return Card(
      color: scheme.errorContainer,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(Icons.key_off_outlined, color: scheme.onErrorContainer),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                '尚未配置可用的 AI Provider 或密钥。请先前往「设置 → AI」添加 Provider 并填写 API Key。',
                style: TextStyle(color: scheme.onErrorContainer, height: 1.5),
              ),
            ),
            const SizedBox(width: 8),
            TextButton(
              onPressed: () => context.push('/settings/ai'),
              child: const Text('去配置'),
            ),
          ],
        ),
      ),
    );
  }

  Widget _errorCard(String message) {
    final scheme = Theme.of(context).colorScheme;
    return Card(
      color: scheme.errorContainer,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(Icons.error_outline, color: scheme.onErrorContainer),
            const SizedBox(width: 12),
            Expanded(
              child: Text(message,
                  style: TextStyle(color: scheme.onErrorContainer, height: 1.5)),
            ),
            const SizedBox(width: 8),
            TextButton(
              onPressed: () => context.push('/settings/ai'),
              child: const Text('去配置'),
            ),
          ],
        ),
      ),
    );
  }

  Widget _inputCard() {
    return SectionCard(
      title: '输入信息',
      icon: Icons.auto_awesome,
      trailing: _imagePath == null
          ? null
          : IconButton(
              tooltip: '移除图片',
              icon: const Icon(Icons.close, size: 18),
              onPressed: () => setState(() => _imagePath = null),
            ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          TextField(
            controller: _inputCtrl,
            minLines: 4,
            maxLines: 10,
            decoration: const InputDecoration(
              labelText: '粘贴一段文字（旧简历片段、聊天记录、获奖信息…）',
              alignLabelWithHint: true,
              border: OutlineInputBorder(),
            ),
          ),
          if (_imagePath != null) ...[
            const SizedBox(height: 8),
            Row(
              children: [
                const Icon(Icons.image_outlined, size: 18),
                const SizedBox(width: 6),
                Expanded(
                  child: Text(
                    _imagePath!.split(Platform.pathSeparator).last,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                        color: Theme.of(context).colorScheme.onSurfaceVariant),
                  ),
                ),
              ],
            ),
          ],
          const SizedBox(height: 12),
          Row(
            children: [
              OutlinedButton.icon(
                onPressed: _analyzing ? null : _pickImage,
                icon: const Icon(Icons.image_outlined),
                label: const Text('选择图片'),
              ),
              const SizedBox(width: 12),
              FilledButton.icon(
                onPressed: _analyzing ? null : _analyze,
                icon: _analyzing
                    ? const SizedBox(
                        width: 16,
                        height: 16,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Icon(Icons.auto_awesome),
                label: Text(_analyzing ? '分析中…' : 'AI 分析'),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _draftCard() {
    final draft = _draft!;
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
      title: '确认草稿',
      icon: Icons.fact_check_outlined,
      trailing: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          _confidenceChip(draft.confidence),
          const SizedBox(width: 8),
          FilledButton(
            onPressed: _saving ? null : _save,
            child: Text(_saving ? '保存中…' : '保存'),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          InputDecorator(
            decoration: const InputDecoration(
              labelText: '分类',
              border: OutlineInputBorder(),
            ),
            child: DropdownButtonHideUnderline(
              child: DropdownButton<String>(
                isExpanded: true,
                value: effective,
                items: [
                  for (final c in items)
                    DropdownMenuItem(
                      value: c.slug,
                      child: Text('${c.label}（${c.slug}）'),
                    ),
                ],
                onChanged: (v) =>
                    setState(() => _category = v ?? effective),
              ),
            ),
          ),
          const SizedBox(height: 12),
          _textField(_titleCtrl, '标题'),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(child: _textField(_orgCtrl, '机构/公司/学校')),
              const SizedBox(width: 12),
              Expanded(child: _textField(_roleCtrl, '职位/角色')),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(child: _textField(_locCtrl, '地点')),
              const SizedBox(width: 12),
              Expanded(child: _textField(_startCtrl, '开始 (YYYY-MM)')),
              const SizedBox(width: 12),
              Expanded(child: _textField(_endCtrl, '结束 (空=至今)')),
            ],
          ),
          const SizedBox(height: 12),
          _textField(_descCtrl, '描述（Markdown）', minLines: 3, maxLines: 8),
          const SizedBox(height: 8),
          _listEditor('亮点 highlights', _highlightCtrls, _addTo, _removeFrom),
          _listEditor('标签 tags', _tagCtrls, _addTo, _removeFrom),
          const SizedBox(height: 8),
          _fieldsEditor(),
          if (draft.missingQuestions.isNotEmpty) ...[
            const SizedBox(height: 8),
            _missingQuestions(draft.missingQuestions),
          ],
        ],
      ),
    );
  }

  Widget _textField(
    TextEditingController controller,
    String label, {
    int minLines = 1,
    int maxLines = 1,
  }) {
    return TextField(
      controller: controller,
      minLines: minLines,
      maxLines: maxLines,
      decoration: InputDecoration(labelText: label, border: const OutlineInputBorder()),
    );
  }

  Widget _confidenceChip(double confidence) {
    final scheme = Theme.of(context).colorScheme;
    return Chip(
      avatar: Icon(
        confidence >= 0.75
            ? Icons.verified_outlined
            : Icons.help_outline,
        size: 16,
      ),
      label: Text('置信度 ${(confidence * 100).round()}%'),
      backgroundColor:
          confidence >= 0.75 ? scheme.secondaryContainer : scheme.surfaceContainerHighest,
      visualDensity: VisualDensity.compact,
    );
  }

  Widget _listEditor(
    String title,
    List<TextEditingController> list,
    void Function(List<TextEditingController>) onAdd,
    void Function(List<TextEditingController>, int) onRemove,
  ) {
    return Padding(
      padding: const EdgeInsets.only(top: 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(title,
                    style: Theme.of(context).textTheme.labelLarge),
              ),
              IconButton(
                tooltip: '添加',
                icon: const Icon(Icons.add, size: 18),
                onPressed: () => onAdd(list),
              ),
            ],
          ),
          for (var i = 0; i < list.length; i++)
            Padding(
              padding: const EdgeInsets.only(bottom: 6),
              child: Row(
                children: [
                  Expanded(child: _textField(list[i], '')),
                  IconButton(
                    tooltip: '删除',
                    icon: const Icon(Icons.remove_circle_outline, size: 18),
                    onPressed: () => onRemove(list, i),
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }

  Widget _fieldsEditor() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Expanded(
              child: Text('专属字段 fields',
                  style: Theme.of(context).textTheme.labelLarge),
            ),
            IconButton(
              tooltip: '添加字段',
              icon: const Icon(Icons.add, size: 18),
              onPressed: () =>
                  setState(() => _fieldRows.add(_FieldRow('', ''))),
            ),
          ],
        ),
        for (var i = 0; i < _fieldRows.length; i++)
          Padding(
            padding: const EdgeInsets.only(bottom: 6),
            child: Row(
              children: [
                Expanded(
                  flex: 2,
                  child: _textField(_fieldRows[i].keyCtrl, '键'),
                ),
                const SizedBox(width: 8),
                Expanded(
                  flex: 3,
                  child: _textField(_fieldRows[i].valueCtrl, '值'),
                ),
                IconButton(
                  tooltip: '删除',
                  icon: const Icon(Icons.remove_circle_outline, size: 18),
                  onPressed: () => setState(() {
                    final row = _fieldRows.removeAt(i);
                    row.dispose();
                  }),
                ),
              ],
            ),
          ),
      ],
    );
  }

  Widget _missingQuestions(List<String> questions) {
    final scheme = Theme.of(context).colorScheme;
    return Card(
      color: scheme.tertiaryContainer,
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.help_outline,
                    size: 18, color: scheme.onTertiaryContainer),
                const SizedBox(width: 8),
                Text('建议补充',
                    style: TextStyle(
                        color: scheme.onTertiaryContainer,
                        fontWeight: FontWeight.w600)),
              ],
            ),
            const SizedBox(height: 6),
            for (final q in questions)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 2),
                child: Text('• $q',
                    style: TextStyle(
                        color: scheme.onTertiaryContainer, height: 1.4)),
              ),
          ],
        ),
      ),
    );
  }
}

/// fields 编辑行的控制器对。
class _FieldRow {
  _FieldRow(String key, String value)
      : keyCtrl = TextEditingController(text: key),
        valueCtrl = TextEditingController(text: value);

  final TextEditingController keyCtrl;
  final TextEditingController valueCtrl;

  void dispose() {
    keyCtrl.dispose();
    valueCtrl.dispose();
  }
}
