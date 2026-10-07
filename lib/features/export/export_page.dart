/// 智能导出：问卷 → 选 Provider → 调研/裁剪/渲染，带阶段进度。
library;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/widgets/common.dart';
import '../../core/widgets/term_info.dart';
import '../../data/models/ai_provider.dart';
import '../../data/models/export_request.dart';
import '../../data/models/target_profile.dart';
import '../../data/providers.dart';
import '../../data/repositories/resume_repository.dart';
import '../../services/ai/llm_client.dart';
import '../../services/export/export_service.dart';
import '../../services/render/templates.dart';
import 'template_preview.dart';

class ExportPage extends ConsumerStatefulWidget {
  const ExportPage({super.key, this.existing});

  /// 非空表示「重新生成/更新」同一份简历（回填问卷并复用其 id）。
  final ResumeMeta? existing;

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
  final _jd = TextEditingController();

  String _purpose = '求职';
  int _pageLimit = 1;
  String _language = 'zh';
  String _style = 'concise';
  String _tone = 'professional';
  bool _research = true;
  bool _appendix = false;

  /// 目标画像（级别校准 + 赛道加权）。
  String _level = TargetLevel.mid.id;
  String _careerStage = CareerStage.early.id;
  String _track = Track.general.id;

  /// 当前模板；用户手动选择后不再被岗位推荐覆盖。
  String _templateId = ResumeTemplates.defaultId;
  bool _templateTouched = false;

  bool _busy = false;
  String? _stage;

  @override
  void initState() {
    super.initState();
    final r = widget.existing?.request;
    if (r != null) {
      _role.text = r.targetRole;
      _company.text = r.targetCompany;
      _industry.text = r.industry;
      _emphasis.text = r.emphasis;
      _mustInclude.text = r.mustInclude.join('，');
      _exclude.text = r.exclude.join('，');
      _notes.text = r.extraNotes;
      _jd.text = r.jobDescription;
      _purpose = r.purpose;
      _pageLimit = r.pageLimit;
      _language = r.language;
      _style = r.style;
      _tone = r.tone;
      _research = r.researchEnabled;
      _appendix = r.appendixEnabled;
      _level = r.targetLevel;
      _careerStage = r.careerStage;
      _track = r.track;
      _templateId = widget.existing?.templateId ?? r.templateId;
      _templateTouched = true;
    }
  }

  @override
  void dispose() {
    _role.dispose();
    _company.dispose();
    _industry.dispose();
    _emphasis.dispose();
    _mustInclude.dispose();
    _exclude.dispose();
    _notes.dispose();
    _jd.dispose();
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
      jobDescription: _jd.text.trim(),
      appendixEnabled: _appendix,
      extraNotes: _notes.text.trim(),
      templateId: _templateId,
      targetLevel: _level,
      careerStage: _careerStage,
      track: _track,
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

    // 第一步：先做取舍计划（可能产生追问）。
    setState(() => _stage = '制定取舍计划');
    final planRes = await service.makePlan(
      full: full,
      request: request,
      baseUrl: provider.baseUrl,
      apiKey: apiKey.trim(),
      model: provider.model,
    );
    final plan = planRes.valueOrNull;

    // 第二步：若有影响关键事实的追问 → 让用户补充（可跳过）。
    var answers = const <String>[];
    if (mounted && plan != null && plan.openQuestions.isNotEmpty) {
      setState(() => _stage = null);
      answers = await _askQuestions(plan.openQuestions) ?? const [];
      if (!mounted) return;
      setState(() => _stage = '按计划改写');
    }

    final result = await service.generate(
      full: full,
      request: request,
      providerId: provider.id,
      baseUrl: provider.baseUrl,
      apiKey: apiKey.trim(),
      model: provider.model,
      existingMeta: widget.existing,
      plan: plan,
      answers: answers,
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

  /// 追问弹窗：逐条填空，可整体跳过。返回 null 表示取消（按跳过处理）。
  Future<List<String>?> _askQuestions(List<String> questions) async {
    final ctrls = [for (final _ in questions) TextEditingController()];
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('补充几条信息，简历会更准'),
        content: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 520),
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('（可留空跳过，不影响生成）',
                    style: TextStyle(
                        color: Theme.of(ctx).colorScheme.onSurfaceVariant,
                        fontSize: 12.5)),
                const SizedBox(height: 10),
                for (var i = 0; i < questions.length; i++) ...[
                  Text(questions[i], style: const TextStyle(height: 1.4)),
                  const SizedBox(height: 6),
                  TextField(
                    controller: ctrls[i],
                    decoration: const InputDecoration(
                      isDense: true,
                      border: OutlineInputBorder(),
                      hintText: '可留空',
                    ),
                  ),
                  const SizedBox(height: 14),
                ],
              ],
            ),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('跳过'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('继续生成'),
          ),
        ],
      ),
    );
    final out = <String>[];
    for (var i = 0; i < questions.length; i++) {
      final v = ctrls[i].text.trim();
      if (v.isNotEmpty) out.add('${questions[i]} → $v');
      ctrls[i].dispose();
    }
    return ok == true ? out : const [];
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
      appBar: AppBar(
        title: Text(widget.existing == null ? '智能导出' : '更新定向简历'),
      ),
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 760),
          child: ListView(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 32),
            children: [
              SectionCard(
                title: '目标画像',
                icon: Icons.my_location,
                child: Column(
                  children: [
                    _profilePicker(
                      label: '目标级别',
                      tipTitle: '目标级别',
                      tipPlain: '这份简历要投的职级。不同级别看重的东西不同：'
                          '校招/初级看潜力与执行，高级看影响范围（scope），管理岗看团队与业绩。',
                      value: _level,
                      options: [
                        for (final c in TargetLevel.all) (c.id, c.label, c.plain),
                      ],
                      onChanged: (v) => setState(() => _level = v),
                    ),
                    const SizedBox(height: 12),
                    _profilePicker(
                      label: '职业阶段',
                      tipTitle: '职业阶段',
                      tipPlain: '你现在所处的位置。它决定简历重点：'
                          '在校生突出教育/项目，转行突出可迁移能力，资深突出领导力与结果。',
                      value: _careerStage,
                      options: [
                        for (final c in CareerStage.all) (c.id, c.label, c.plain),
                      ],
                      onChanged: (v) => setState(() => _careerStage = v),
                    ),
                    const SizedBox(height: 12),
                    _profilePicker(
                      label: '赛道',
                      tipTitle: '赛道',
                      tipPlain: '目标行业方向。不同赛道看重的证据不一样，'
                          '会影响怎么取舍和排版。不确定选「通用」，会按岗位名自动判断。',
                      value: _track,
                      options: [for (final c in Track.all) (c.id, c.label, c.plain)],
                      onChanged: (v) => setState(() => _track = v),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 12),
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
                      controller: _jd,
                      maxLines: 5,
                      decoration: const InputDecoration(
                        labelText: '目标岗位 JD（可选，粘贴原文以做深度适配）',
                        alignLabelWithHint: true,
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
                    SwitchListTile(
                      contentPadding: EdgeInsets.zero,
                      title: const Text('附参考材料附录'),
                      subtitle: const Text('把被选用经历的佐证材料排为附录页，并在正文交叉引用〔A-x〕'),
                      value: _appendix,
                      onChanged: (v) => setState(() => _appendix = v),
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

  /// 模板选择卡片：横向可滚动的带缩略图卡片 + 说明 + 章节顺序预览。
  Widget _templateCard() {
    final selected = ResumeTemplates.byId(_templateId);
    // 当前岗位的推荐模板（用于标记与默认预选）。
    final recId = ResumeTemplates.recommendFor([_role.text]).first.id;
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
      trailing: TextButton.icon(
        onPressed: () => showTemplatePreviewDialog(context, selected),
        icon: const Icon(Icons.zoom_in, size: 18),
        label: const Text('放大预览'),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            height: 264,
            child: ListView.separated(
              scrollDirection: Axis.horizontal,
              itemCount: ResumeTemplates.all.length,
              separatorBuilder: (_, __) => const SizedBox(width: 10),
              itemBuilder: (_, i) {
                final t = ResumeTemplates.all[i];
                return _templateOption(
                  t,
                  isSelected: t.id == selected.id,
                  isRecommended: t.id == recId,
                );
              },
            ),
          ),
          const SizedBox(height: 12),
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

  /// 单张模板卡片：缩略图 + 名称 + 描述 + bestFor；点击选中并写入模板 id。
  Widget _templateOption(
    ResumeTemplate t, {
    required bool isSelected,
    required bool isRecommended,
  }) {
    final scheme = Theme.of(context).colorScheme;
    final text = Theme.of(context).textTheme;
    return InkWell(
      onTap: () => setState(() {
        _templateId = t.id;
        _templateTouched = true;
      }),
      borderRadius: BorderRadius.circular(12),
      child: Container(
        width: 164,
        padding: const EdgeInsets.all(10),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: isSelected ? scheme.primary : scheme.outlineVariant,
            width: isSelected ? 2 : 1,
          ),
          color: isSelected
              ? scheme.primaryContainer.withValues(alpha: 0.28)
              : null,
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Center(child: TemplatePreview(template: t, width: 108)),
            const SizedBox(height: 8),
            Row(
              children: [
                Expanded(
                  child: Text(
                    t.name,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: text.titleSmall,
                  ),
                ),
                if (isRecommended)
                  Container(
                    margin: const EdgeInsets.only(left: 4),
                    padding:
                        const EdgeInsets.symmetric(horizontal: 5, vertical: 1),
                    decoration: BoxDecoration(
                      color: scheme.tertiaryContainer,
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: Text(
                      '推荐',
                      style: text.labelSmall
                          ?.copyWith(color: scheme.onTertiaryContainer),
                    ),
                  ),
                if (isSelected)
                  Padding(
                    padding: const EdgeInsets.only(left: 4),
                    child:
                        Icon(Icons.check_circle, size: 16, color: scheme.primary),
                  ),
              ],
            ),
            const SizedBox(height: 2),
            Text(
              t.description,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: text.bodySmall,
            ),
            const SizedBox(height: 4),
            Text(
              '适配：${t.bestFor.take(3).join(' / ')}',
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: text.labelSmall?.copyWith(color: scheme.onSurfaceVariant),
            ),
          ],
        ),
      ),
    );
  }

  /// 带「大白话解释」气泡的画像选择器。
  Widget _profilePicker({
    required String label,
    required String tipTitle,
    required String tipPlain,
    required String value,
    required List<(String, String, String)> options,
    required ValueChanged<String> onChanged,
  }) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        Expanded(
          child: DropdownButtonFormField<String>(
            initialValue: value,
            isExpanded: true,
            decoration: InputDecoration(
              labelText: label,
              border: const OutlineInputBorder(),
            ),
            items: [
              for (final (id, text, _) in options)
                DropdownMenuItem<String>(value: id, child: Text(text)),
            ],
            onChanged: (v) {
              if (v != null) onChanged(v);
            },
          ),
        ),
        InfoDot(title: tipTitle, plain: tipPlain),
      ],
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
