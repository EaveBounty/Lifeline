/// 智能导出：问卷 → 选 Provider → 调研/裁剪/渲染，带阶段进度。
library;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/widgets/common.dart';
import '../../data/models/ai_provider.dart';
import '../../data/models/export_request.dart';
import '../../data/providers.dart';
import '../../data/repositories/resume_repository.dart';
import '../../services/ai/llm_client.dart';
import '../../services/export/export_service.dart';
import '../../services/render/templates.dart';

class ExportPage extends ConsumerStatefulWidget {
  const ExportPage({super.key});

  @override
  ConsumerState<ExportPage> createState() => _ExportPageState();
}

class _ExportPageState extends ConsumerState<ExportPage> {
  final _role = TextEditingController();
  final _company = TextEditingController();
  final _industry = TextEditingController();
  final _emphasis = TextEditingController();
  final _mustInclude = TextEditingController();
  final _exclude = TextEditingController();
  final _notes = TextEditingController();

  String _purpose = '求职';
  int _pageLimit = 1;
  String _language = 'zh';
  String _style = 'concise';
  String _tone = 'professional';
  bool _research = true;

  /// 当前模板；用户手动选择后不再被岗位推荐覆盖。
  String _templateId = ResumeTemplates.defaultId;
  bool _templateTouched = false;

  bool _busy = false;
  String? _stage;

  @override
  void dispose() {
    _role.dispose();
    _company.dispose();
    _industry.dispose();
    _emphasis.dispose();
    _mustInclude.dispose();
    _exclude.dispose();
    _notes.dispose();
    super.dispose();
  }

  List<String> _list(String raw) => raw
      .split(RegExp(r'[\n,，、;；]+'))
      .map((e) => e.trim())
      .where((e) => e.isNotEmpty)
      .toList();

  Future<void> _submit() async {
    final messenger = ScaffoldMessenger.of(context);
    final root = ref.read(syncRootProvider).path;
    if (root == null) {
      messenger.showSnackBar(const SnackBar(content: Text('尚未挂载同步根')));
      return;
    }
    final full = ref.read(fullResumeProvider);
    if (full == null) {
      messenger.showSnackBar(const SnackBar(content: Text('简历尚未编译完成，请稍后重试')));
      return;
    }

    final settings = ref.read(settingsProvider).value;
    final providers = (settings?.providers ?? const <AiProvider>[])
        .where((p) => p.enabled)
        .toList();
    if (providers.isEmpty) {
      await _guideToAi('尚未配置任何 AI Provider，无法进行智能导出。');
      return;
    }

    final provider = await _pickProvider(providers, settings?.defaultAiProviderId);
    if (provider == null) return;

    final apiKey = await ref.read(secretStoreProvider).read(provider.keyRef);
    if (apiKey == null || apiKey.trim().isEmpty) {
      if (!mounted) return;
      await _guideToAi('Provider「${provider.name}」尚未配置 API Key。');
      return;
    }

    final request = ExportRequest(
      purpose: _purpose,
      targetRole: _role.text.trim(),
      targetCompany: _company.text.trim(),
      industry: _industry.text.trim(),
      pageLimit: _pageLimit,
      language: _language,
      style: _style,
      tone: _tone,
      emphasis: _emphasis.text.trim(),
      mustInclude: _list(_mustInclude.text),
      exclude: _list(_exclude.text),
      researchEnabled: _research,
      extraNotes: _notes.text.trim(),
      templateId: _templateId,
    );

    setState(() {
      _busy = true;
      _stage = '准备中';
    });

    final service = ExportService(
      llm: LlmClient(),
      repo: ResumeRepository(root),
      syncRoot: root,
      formats: settings?.defaultExportFormats,
    );
    final result = await service.generate(
      full: full,
      request: request,
      providerId: provider.id,
      baseUrl: provider.baseUrl,
      apiKey: apiKey.trim(),
      model: provider.model,
      onStage: (stage) {
        if (mounted) setState(() => _stage = stage);
      },
    );

    if (!mounted) return;
    setState(() {
      _busy = false;
      _stage = null;
    });

    result.when(
      ok: (meta) {
        messenger.showSnackBar(
          SnackBar(content: Text('已生成「${meta.name}」共 ${meta.files.length} 个文件')),
        );
        context.go('/resumes');
      },
      err: (msg, _) {
        messenger.showSnackBar(SnackBar(content: Text(msg)));
      },
    );
  }

  Future<AiProvider?> _pickProvider(
    List<AiProvider> providers,
    String? defaultId,
  ) {
    // 默认 Provider 置顶并标注（预选）。
    final ordered = [...providers]
      ..sort((a, b) {
        final da = a.id == defaultId ? 0 : 1;
        final db = b.id == defaultId ? 0 : 1;
        return da.compareTo(db);
      });
    return showDialog<AiProvider>(
      context: context,
      builder: (ctx) => SimpleDialog(
        title: const Text('选择 AI Provider'),
        children: [
          for (final p in ordered)
            SimpleDialogOption(
              onPressed: () => Navigator.pop(ctx, p),
              child: ListTile(
                dense: true,
                title: Text(p.id == defaultId ? '${p.name}（默认）' : p.name),
                subtitle: Text('${p.model} · ${p.baseUrl}'),
                trailing: p.id == defaultId
                    ? const Icon(Icons.star, size: 18)
                    : null,
              ),
            ),
        ],
      ),
    );
  }

  Future<void> _guideToAi(String message) async {
    final go = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('需要配置 AI'),
        content: Text(message),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('取消'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('前往设置'),
          ),
        ],
      ),
    );
    if (go == true && mounted) context.push('/settings/ai');
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('智能导出')),
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 760),
          child: ListView(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 32),
            children: [
              SectionCard(
                title: '基本要求',
                icon: Icons.work_outline,
                child: Column(
                  children: [
                    _dropdown(
                      label: '用途',
                      value: _purpose,
                      items: const ['求职', '申请', '投稿', '内部汇报', '其他'],
                      onChanged: (v) => setState(() => _purpose = v),
                    ),
                    const SizedBox(height: 12),
                    TextField(
                      controller: _role,
                      onChanged: (v) {
                        if (_templateTouched) return;
                        final top = ResumeTemplates.recommendFor([v]).first.id;
                        setState(() => _templateId = top);
                      },
                      decoration: const InputDecoration(
                        labelText: '目标岗位',
                        border: OutlineInputBorder(),
                      ),
                    ),
                    const SizedBox(height: 12),
                    TextField(
                      controller: _company,
                      decoration: const InputDecoration(
                        labelText: '目标企业',
                        border: OutlineInputBorder(),
                      ),
                    ),
                    const SizedBox(height: 12),
                    TextField(
                      controller: _industry,
                      decoration: const InputDecoration(
                        labelText: '行业',
                        border: OutlineInputBorder(),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 12),
              SectionCard(
                title: '长度与风格',
                icon: Icons.tune,
                child: Column(
                  children: [
                    _dropdown<int>(
                      label: '页数',
                      value: _pageLimit,
                      items: const [1, 2, 3, 0],
                      labelOf: (v) => v == 0 ? '不限' : '$v 页',
                      onChanged: (v) => setState(() => _pageLimit = v),
                    ),
                    const SizedBox(height: 12),
                    _dropdown(
                      label: '语言',
                      value: _language,
                      items: const ['zh', 'en'],
                      labelOf: (v) => v == 'zh' ? '中文' : 'English',
                      onChanged: (v) => setState(() => _language = v),
                    ),
                    const SizedBox(height: 12),
                    _dropdown(
                      label: '风格',
                      value: _style,
                      items: const ['concise', 'detailed', 'academic', 'creative'],
                      onChanged: (v) => setState(() => _style = v),
                    ),
                    const SizedBox(height: 12),
                    _dropdown(
                      label: '语气',
                      value: _tone,
                      items: const ['professional', 'energetic', 'modest'],
                      onChanged: (v) => setState(() => _tone = v),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 12),
              _templateCard(),
              const SizedBox(height: 12),
              SectionCard(
                title: '取舍与强调',
                icon: Icons.filter_alt_outlined,
                child: Column(
                  children: [
                    TextField(
                      controller: _emphasis,
                      decoration: const InputDecoration(
                        labelText: '希望突出什么',
                        border: OutlineInputBorder(),
                      ),
                    ),
                    const SizedBox(height: 12),
                    TextField(
                      controller: _mustInclude,
                      maxLines: 3,
                      decoration: const InputDecoration(
                        labelText: '必须包含（逗号/换行分隔）',
                        border: OutlineInputBorder(),
                      ),
                    ),
                    const SizedBox(height: 12),
                    TextField(
                      controller: _exclude,
                      maxLines: 2,
                      decoration: const InputDecoration(
                        labelText: '需要排除（逗号/换行分隔）',
                        border: OutlineInputBorder(),
                      ),
                    ),
                    const SizedBox(height: 8),
                    SwitchListTile(
                      contentPadding: EdgeInsets.zero,
                      title: const Text('启用岗位调研'),
                      subtitle: const Text('联网/模型分析目标岗位关键词，用于裁剪'),
                      value: _research,
                      onChanged: (v) => setState(() => _research = v),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 12),
              SectionCard(
                title: '补充说明',
                icon: Icons.notes,
                child: TextField(
                  controller: _notes,
                  maxLines: 3,
                  decoration: const InputDecoration(
                    hintText: '其他要求或背景…',
                    border: OutlineInputBorder(),
                  ),
                ),
              ),
              const SizedBox(height: 20),
              FilledButton.icon(
                onPressed: _busy ? null : _submit,
                icon: _busy
                    ? const SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Icon(Icons.auto_awesome),
                label: Text(_busy ? (_stage ?? '生成中…') : '生成定向简历'),
              ),
            ],
          ),
        ),
      ),
    );
  }

  /// 模板选择卡片：下拉 + 说明 + 章节顺序预览。
  Widget _templateCard() {
    final selected = ResumeTemplates.byId(_templateId);
    final full = ref.watch(fullResumeProvider);
    final order = full == null
        ? const <String>[]
        : ResumeTemplates.orderSections(full.sections, selected.id)
            .where((s) => s.items.isNotEmpty)
            .map((s) => s.title)
            .toList();
    final body = Theme.of(context).textTheme.bodySmall;
    return SectionCard(
      title: '模板风格',
      icon: Icons.style_outlined,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          DropdownButtonFormField<String>(
            initialValue: selected.id,
            decoration: const InputDecoration(
              labelText: '选择模板',
              border: OutlineInputBorder(),
            ),
            items: [
              for (final t in ResumeTemplates.all)
                DropdownMenuItem(
                  value: t.id,
                  child: Text('${t.name}  ·  ${t.layout}'),
                ),
            ],
            onChanged: (v) {
              if (v != null) {
                setState(() {
                  _templateId = v;
                  _templateTouched = true;
                });
              }
            },
          ),
          const SizedBox(height: 10),
          Text(selected.description, style: body),
          const SizedBox(height: 6),
          Text('适配：${selected.bestFor.join(' / ')}', style: body),
          const SizedBox(height: 6),
          Wrap(
            spacing: 6,
            runSpacing: 4,
            children: [
              for (final tag in selected.tags)
                Chip(
                  label: Text(tag),
                  visualDensity: VisualDensity.compact,
                  materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                ),
            ],
          ),
          if (order.isNotEmpty) ...[
            const SizedBox(height: 8),
            Text('章节顺序预览：', style: Theme.of(context).textTheme.labelMedium),
            const SizedBox(height: 2),
            Text(order.join('  →  '), style: body),
          ],
        ],
      ),
    );
  }

  Widget _dropdown<T>({
    required String label,
    required T value,
    required List<T> items,
    required ValueChanged<T> onChanged,
    String Function(T)? labelOf,
  }) {
    return DropdownButtonFormField<T>(
      initialValue: value,
      decoration: InputDecoration(
        labelText: label,
        border: const OutlineInputBorder(),
      ),
      items: [
        for (final item in items)
          DropdownMenuItem<T>(
            value: item,
            child: Text(labelOf == null ? '$item' : labelOf(item)),
          ),
      ],
      onChanged: (v) {
        if (v != null) onChanged(v);
      },
    );
  }
}
