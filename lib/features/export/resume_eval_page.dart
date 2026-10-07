/// 简历「一体两面」评估页：
/// - 岗位适配诊断（针对性）：硬性要求对照 / 缺漏 / 按边际效益排序的提升行动。
/// - 客观质量评分（通用）：总分 / 维度 / 优点不足。
library;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../data/models/ai_provider.dart';
import '../../data/models/export_request.dart';
import '../../data/models/resume_doc.dart';
import '../../data/models/resume_eval.dart';
import '../../data/providers.dart';
import '../../data/repositories/resume_repository.dart';
import '../../services/ai/llm_client.dart';
import '../../services/export/export_service.dart';
import '../../services/export/resume_eval_providers.dart';

class ResumeEvalPage extends ConsumerStatefulWidget {
  const ResumeEvalPage({super.key, required this.meta});

  final ResumeMeta meta;

  @override
  ConsumerState<ResumeEvalPage> createState() => _ResumeEvalPageState();
}

class _ResumeEvalPageState extends ConsumerState<ResumeEvalPage> {
  late ResumeMeta _meta;
  ResumeDocument? _doc;
  ExportRequest _request = const ExportRequest();
  ResumeEvaluation? _eval;
  bool _loading = true;
  bool _aiRunning = false;
  bool _revising = false;
  bool _checking = false;
  String? _error;
  int _tab = 0;
  final Set<String> _expanded = {};
  final Set<String> _doneActions = {};
  List<MaterialCheck> _materialChecks = const [];

  @override
  void initState() {
    _meta = widget.meta;
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final root = ref.read(syncRootProvider).path;
    if (root == null) {
      setState(() {
        _loading = false;
        _error = '尚未挂载同步根。';
      });
      return;
    }
    final spec = await ResumeRepository(root).loadSpec(_meta.id);
    if (!mounted) return;
    if (spec == null) {
      setState(() {
        _loading = false;
        _error = '未找到该简历的 spec.json（可能尚未生成或已删除）。';
      });
      return;
    }
    final request = _meta.request ??
        ExportRequest(
          targetRole: _meta.targetRole,
          targetCompany: _meta.targetCompany,
          purpose: _meta.purpose,
        );
    final heuristic = ref
        .read(resumeEvalServiceProvider)
        .evaluateHeuristic(doc: spec, request: request);
    if (!mounted) return;
    setState(() {
      _doc = spec;
      _request = request;
      _eval = _meta.evaluation ?? heuristic;
      _materialChecks = _meta.materialChecks;
      _loading = false;
    });
  }

  Future<void> _save() async {
    final eval = _eval;
    if (eval == null) return;
    final updated = _meta.copyWith(evaluation: eval);
    await ref.read(resumeLibraryProvider.notifier).saveMeta(updated);
    if (!mounted) return;
    setState(() => _meta = updated);
  }

  Future<void> _runAi() async {
    final doc = _doc;
    if (doc == null) return;
    final messenger = ScaffoldMessenger.of(context);
    final settings = ref.read(settingsProvider).value;
    final providers = (settings?.providers ?? const <AiProvider>[])
        .where((p) => p.enabled)
        .toList();
    if (providers.isEmpty) {
      await _guideToAi('尚未配置任何 AI Provider，无法进行 AI 评估。');
      return;
    }
    var provider = providers.first;
    final defaultId = settings?.defaultAiProviderId;
    if (defaultId != null) {
      for (final p in providers) {
        if (p.id == defaultId) {
          provider = p;
          break;
        }
      }
    }
    final apiKey = await ref.read(secretStoreProvider).read(provider.keyRef);
    if (!mounted) return;
    if (apiKey == null || apiKey.trim().isEmpty) {
      await _guideToAi('Provider「${provider.name}」尚未配置 API Key。');
      return;
    }
    setState(() => _aiRunning = true);
    final res = await ref.read(resumeEvalServiceProvider).evaluateWithAi(
          doc: doc,
          request: _request,
          baseUrl: provider.baseUrl,
          apiKey: apiKey.trim(),
          model: provider.model,
        );
    if (!mounted) return;
    setState(() => _aiRunning = false);
    res.when(
      ok: (eval) {
        setState(() => _eval = eval);
        _save();
        messenger.showSnackBar(const SnackBar(content: Text('AI 评估完成')));
      },
      err: (msg, _) => messenger.showSnackBar(
        SnackBar(content: Text('AI 评估失败，保留当前结果：$msg')),
      ),
    );
  }

  /// 解析默认 Provider 与密钥；不可用时引导配置并返回 null。
  Future<(AiProvider, String)?> _resolveProvider() async {
    final settings = ref.read(settingsProvider).value;
    final providers = (settings?.providers ?? const <AiProvider>[])
        .where((p) => p.enabled)
        .toList();
    if (providers.isEmpty) {
      await _guideToAi('尚未配置任何 AI Provider。');
      return null;
    }
    var provider = providers.first;
    final defaultId = settings?.defaultAiProviderId;
    if (defaultId != null) {
      for (final p in providers) {
        if (p.id == defaultId) {
          provider = p;
          break;
        }
      }
    }
    final apiKey = await ref.read(secretStoreProvider).read(provider.keyRef);
    if (!mounted) return null;
    if (apiKey == null || apiKey.trim().isEmpty) {
      await _guideToAi('Provider「${provider.name}」尚未配置 API Key。');
      return null;
    }
    return (provider, apiKey.trim());
  }

  ExportService _service(String root) => ExportService(
        llm: LlmClient(),
        repo: ResumeRepository(root),
        syncRoot: root,
        formats: ref.read(settingsProvider).value?.defaultExportFormats,
      );

  /// 评估 → 针对性修订（重写 spec + 重渲染 + 重评估）。
  Future<void> _runRevise() async {
    final doc = _doc;
    if (doc == null) return;
    final messenger = ScaffoldMessenger.of(context);
    if (_meta.evaluation == null) {
      messenger.showSnackBar(const SnackBar(content: Text('请先运行一次评估再修订。')));
      return;
    }
    final resolved = await _resolveProvider();
    if (resolved == null) return;
    final (provider, apiKey) = resolved;
    final root = ref.read(syncRootProvider).path;
    if (root == null) return;
    setState(() => _revising = true);
    final full = ref.read(fullResumeProvider) ?? doc;
    final res = await _service(root).revise(
      meta: _meta,
      spec: doc,
      full: full,
      baseUrl: provider.baseUrl,
      apiKey: apiKey,
      model: provider.model,
    );
    if (!mounted) return;
    setState(() => _revising = false);
    res.when(
      ok: (meta) {
        messenger.showSnackBar(
          const SnackBar(content: Text('已按评估修订，重新生成并重评估')),
        );
        _meta = meta;
        _load();
      },
      err: (msg, _) => messenger.showSnackBar(SnackBar(content: Text('修订失败：$msg'))),
    );
  }

  /// 参考材料图文核对（需 appendix 含图片材料）。
  Future<void> _checkMaterials() async {
    final doc = _doc;
    if (doc == null) return;
    final messenger = ScaffoldMessenger.of(context);
    if (doc.appendix.isEmpty) {
      messenger.showSnackBar(
        const SnackBar(content: Text('本简历未附参考材料附录（生成时勾选「附参考材料附录」）。')),
      );
      return;
    }
    final resolved = await _resolveProvider();
    if (resolved == null) return;
    final (provider, apiKey) = resolved;
    final root = ref.read(syncRootProvider).path;
    if (root == null) return;
    if (!provider.supportsVision) {
      messenger.showSnackBar(
        SnackBar(content: Text('当前模型「${provider.name}」不支持图片识别，无法核对材料。')),
      );
      return;
    }
    setState(() => _checking = true);
    final res = await _service(root).checkMaterials(
      doc: doc,
      baseUrl: provider.baseUrl,
      apiKey: apiKey,
      model: provider.model,
    );
    if (!mounted) return;
    setState(() => _checking = false);
    res.when(
      ok: (checks) {
        setState(() => _materialChecks = checks);
        final updated = _meta.copyWith(materialChecks: checks);
        _meta = updated;
        ref.read(resumeLibraryProvider.notifier).saveMeta(updated);
        messenger.showSnackBar(SnackBar(content: Text('材料核对完成（${checks.length} 条）')));
      },
      err: (msg, _) => messenger.showSnackBar(SnackBar(content: Text('核对失败：$msg'))),
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

  Future<void> _open(String url) async {
    final messenger = ScaffoldMessenger.of(context);
    final uri = Uri.tryParse(url);
    if (uri == null) return;
    try {
      final ok = await launchUrl(uri, mode: LaunchMode.platformDefault);
      if (!ok) {
        messenger.showSnackBar(SnackBar(content: Text('无法打开链接：$url')));
      }
    } catch (_) {
      messenger.showSnackBar(SnackBar(content: Text('无法打开链接：$url')));
    }
  }

  @override
  Widget build(BuildContext context) {
    final providers = ref
            .watch(settingsProvider)
            .value
            ?.providers
            .where((p) => p.enabled)
            .toList() ??
        const <AiProvider>[];

    return Scaffold(
      appBar: AppBar(
        title: const Text('简历评估'),
        actions: [
          IconButton(
            tooltip: '保存评估',
            icon: const Icon(Icons.save_outlined),
            onPressed: _eval == null ? null : _save,
          ),
        ],
      ),
      body: _buildBody(context, providers),
    );
  }

  Widget _buildBody(BuildContext context, List<AiProvider> providers) {
    if (_loading) {
      return const Center(child: CircularProgressIndicator());
    }
    if (_error != null) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Text(_error!, textAlign: TextAlign.center),
        ),
      );
    }
    final eval = _eval;
    if (eval == null) {
      return const Center(child: Text('暂无评估结果。'));
    }

    return Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 860),
        child: ListView(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 32),
          children: [
            _aiButton(context, providers),
            const SizedBox(height: 12),
            _segmented(context, eval),
            const SizedBox(height: 12),
            if (_materialChecks.isNotEmpty) ...[
              _materialSection(context),
              const SizedBox(height: 12),
            ],
            if (_tab == 0)
              ..._fitSections(context, eval.fit)
            else
              ..._objectiveSections(context, eval.objective),
          ],
        ),
      ),
    );
  }

  Widget _aiButton(BuildContext context, List<AiProvider> providers) {
    final canRun = providers.isNotEmpty && _doc != null;
    Widget spinner() => const SizedBox(
          width: 16,
          height: 16,
          child: CircularProgressIndicator(strokeWidth: 2),
        );
    final hasAppendix = _doc?.appendix.isNotEmpty ?? false;
    return Align(
      alignment: Alignment.centerRight,
      child: Wrap(
        spacing: 8,
        runSpacing: 8,
        alignment: WrapAlignment.end,
        children: [
          OutlinedButton.icon(
            onPressed: canRun && !_revising ? _runRevise : null,
            icon: _revising ? spinner() : const Icon(Icons.auto_fix_high),
            label: Text(_revising ? '修订中…' : '按评估修订'),
          ),
          if (hasAppendix)
            OutlinedButton.icon(
              onPressed: canRun && !_checking ? _checkMaterials : null,
              icon: _checking ? spinner() : const Icon(Icons.fact_check_outlined),
              label: Text(_checking ? '核对中…' : '材料核对'),
            ),
          FilledButton.icon(
            onPressed: canRun && !_aiRunning ? _runAi : null,
            icon: _aiRunning ? spinner() : const Icon(Icons.auto_awesome),
            label: Text(_aiRunning ? 'AI 评估中…' : 'AI 精评'),
          ),
        ],
      ),
    );
  }

  Widget _segmented(BuildContext context, ResumeEvaluation eval) {
    return SegmentedButton<int>(
      segments: [
        ButtonSegment(
          value: 0,
          icon: const Icon(Icons.work_outline),
          label: Text('岗位适配诊断 · ${eval.fit.fitScore}'),
        ),
        ButtonSegment(
          value: 1,
          icon: const Icon(Icons.assessment_outlined),
          label: Text('客观质量评分 · ${eval.objective.overall}'),
        ),
      ],
      selected: {_tab},
      onSelectionChanged: (s) => setState(() => _tab = s.first),
    );
  }

  // --- 岗位适配诊断 ---

  List<Widget> _fitSections(BuildContext context, FitAnalysis fit) {
    return [
      _fitHeader(context, fit),
      const SizedBox(height: 12),
      _section(
        context,
        title: '硬性要求对照（${fit.hardRequirements.length}）',
        icon: Icons.fact_check_outlined,
        children: fit.hardRequirements.isEmpty
            ? [const ListTile(dense: true, title: Text('该岗位画像无明确硬性证书要求。'))]
            : [for (final r in fit.hardRequirements) _hardReqTile(context, r)],
      ),
      const SizedBox(height: 12),
      _section(
        context,
        title: '缺漏项（${fit.missing.length}）',
        icon: Icons.report_problem_outlined,
        children: fit.missing.isEmpty
            ? [const ListTile(dense: true, title: Text('未发现明显缺漏。'))]
            : [for (final m in fit.missing) _missingTile(context, m)],
      ),
      const SizedBox(height: 12),
      _section(
        context,
        title: '提升行动清单（按边际效益排序）',
        icon: Icons.trending_up,
        children: [
          for (final a in fit.recommendations) _actionTile(context, a),
        ],
      ),
    ];
  }

  Widget _materialSection(BuildContext context) {
    final theme = Theme.of(context);
    Color colorOf(String v) => switch (v) {
          'ok' => Colors.green.shade600,
          'weak' => Colors.orange.shade700,
          'mismatch' => theme.colorScheme.error,
          _ => theme.colorScheme.onSurfaceVariant,
        };
    String labelOf(String v) => switch (v) {
          'ok' => '材料支持',
          'weak' => '弱支持',
          'mismatch' => '与材料不符',
          _ => '无可用材料',
        };
    return _section(
      context,
      title: '参考材料图文核对（${_materialChecks.length}）',
      icon: Icons.fact_check_outlined,
      children: [
        for (final m in _materialChecks)
          ListTile(
            dense: true,
            leading: Icon(Icons.circle, size: 12, color: colorOf(m.verdict)),
            title: Text('[${m.label}] ${labelOf(m.verdict)}'),
            subtitle: m.note.trim().isEmpty ? null : Text(m.note),
          ),
      ],
    );
  }

  Widget _fitHeader(BuildContext context, FitAnalysis fit) {
    final theme = Theme.of(context);
    final subtitle = [_request.targetRole, _request.targetCompany]
        .where((e) => e.trim().isNotEmpty)
        .join(' · ');
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            _ring(theme, fit.fitScore, label: '适配度'),
            const SizedBox(width: 20),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Flexible(
                        child: Text(
                          _meta.name,
                          style: theme.textTheme.titleMedium,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      const SizedBox(width: 8),
                      Chip(
                        label: Text(
                          fit.roleName ?? '未识别画像',
                          style: const TextStyle(fontSize: 11),
                        ),
                        visualDensity: VisualDensity.compact,
                        materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                      ),
                      const SizedBox(width: 6),
                      Chip(
                        label: Text(
                          _eval?.aiAssisted == true ? 'AI' : '启发式',
                          style: const TextStyle(fontSize: 11),
                        ),
                        visualDensity: VisualDensity.compact,
                        materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                      ),
                    ],
                  ),
                  if (subtitle.isNotEmpty)
                    Text(subtitle,
                        style: TextStyle(color: theme.colorScheme.onSurfaceVariant)),
                  const SizedBox(height: 8),
                  Text(fit.summary),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _hardReqTile(BuildContext context, HardRequirement r) {
    final theme = Theme.of(context);
    final color = _statusColor(r.status, theme.colorScheme);
    final icon = switch (r.status) {
      'have' => Icons.check_circle,
      'partial' => Icons.remove_circle,
      'missing' => Icons.cancel,
      _ => Icons.help_outline,
    };
    return ListTile(
      dense: true,
      leading: Icon(icon, color: color, size: 20),
      title: Row(
        children: [
          Expanded(child: Text(r.name)),
          _tag(theme, _statusLabel(r.status), color),
          const SizedBox(width: 4),
          _tag(
            theme,
            r.importance == 'required' ? '硬性' : '加分',
            r.importance == 'required' ? theme.colorScheme.primary : theme.colorScheme.outline,
          ),
        ],
      ),
      subtitle: Text(
        [
          if (r.evidence.isNotEmpty) '依据：${r.evidence}',
          if (r.note.isNotEmpty) r.note,
        ].join('\n'),
      ),
    );
  }

  Widget _missingTile(BuildContext context, FitMissingItem m) {
    final theme = Theme.of(context);
    final color = m.importance == 'required'
        ? theme.colorScheme.error
        : Colors.orange.shade700;
    return ListTile(
      dense: true,
      leading: Icon(Icons.circle, size: 12, color: color),
      title: Row(
        children: [
          Expanded(child: Text(m.item)),
          _tag(theme, _categoryLabel(m.category), theme.colorScheme.secondary),
          const SizedBox(width: 4),
          _tag(
            theme,
            m.importance == 'required' ? '必需' : '加分',
            color,
          ),
        ],
      ),
      subtitle: Text('${m.why}\n建议：${m.suggestion}'),
      isThreeLine: true,
    );
  }

  Widget _actionTile(BuildContext context, FitAction a) {
    final theme = Theme.of(context);
    final key = '${a.priority}|${a.action}';
    final done = _doneActions.contains(key) || a.done;
    return Padding(
      padding: const EdgeInsets.fromLTRB(12, 8, 12, 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Checkbox(
            value: done,
            visualDensity: VisualDensity.compact,
            onChanged: (v) => setState(() {
              if (v == true) {
                _doneActions.add(key);
              } else {
                _doneActions.remove(key);
              }
            }),
          ),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    CircleAvatar(
                      radius: 12,
                      backgroundColor: theme.colorScheme.primaryContainer,
                      child: Text(
                        '${a.priority}',
                        style: TextStyle(
                          fontSize: 11,
                          color: theme.colorScheme.onPrimaryContainer,
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        a.action,
                        style: TextStyle(
                          fontWeight: FontWeight.w600,
                          decoration: done ? TextDecoration.lineThrough : null,
                        ),
                      ),
                    ),
                    Text(
                      '录取概率 +${a.expectedGain}%',
                      style: TextStyle(
                        color: theme.colorScheme.primary,
                        fontWeight: FontWeight.bold,
                        fontSize: 12,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 4),
                Wrap(
                  spacing: 6,
                  runSpacing: 4,
                  crossAxisAlignment: WrapCrossAlignment.center,
                  children: [
                    _tag(theme, _categoryLabel(a.category), theme.colorScheme.secondary),
                    _tag(theme, _effortLabel(a.effort), theme.colorScheme.outline),
                    if (a.timeEstimate.isNotEmpty)
                      _tag(theme, '耗时 ${a.timeEstimate}', theme.colorScheme.outline),
                  ],
                ),
                if (a.rationale.isNotEmpty) ...[
                  const SizedBox(height: 4),
                  Text(
                    a.rationale,
                    style: TextStyle(
                      color: theme.colorScheme.onSurfaceVariant,
                      fontSize: 12.5,
                    ),
                  ),
                ],
                if (a.resources.isNotEmpty) ...[
                  const SizedBox(height: 6),
                  Wrap(
                    spacing: 6,
                    runSpacing: 6,
                    children: [
                      for (final url in a.resources)
                        ActionChip(
                          avatar: const Icon(Icons.open_in_new, size: 14),
                          label: Text(
                            _shortUrl(url),
                            style: const TextStyle(fontSize: 11),
                          ),
                          visualDensity: VisualDensity.compact,
                          materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                          onPressed: () => _open(url),
                        ),
                    ],
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }

  // --- 客观质量评分 ---

  List<Widget> _objectiveSections(BuildContext context, ObjectiveScore objective) {
    return [
      _objectiveHeader(context, objective),
      const SizedBox(height: 12),
      _section(
        context,
        title: '维度评分',
        icon: Icons.radar,
        children: [for (final d in objective.dimensions) _dimensionTile(context, d)],
      ),
      const SizedBox(height: 12),
      _section(
        context,
        title: '优点与不足',
        icon: Icons.thumb_up_alt_outlined,
        children: [
          _chipRow(
            context,
            '优点',
            objective.strengths,
            Colors.green.shade600,
          ),
          _chipRow(
            context,
            '不足',
            objective.weaknesses,
            Theme.of(context).colorScheme.error,
          ),
        ],
      ),
    ];
  }

  Widget _objectiveHeader(BuildContext context, ObjectiveScore objective) {
    final theme = Theme.of(context);
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Row(
          children: [
            _ring(theme, objective.overall, label: '客观分'),
            const SizedBox(width: 20),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('客观质量评分', style: theme.textTheme.titleMedium),
                  const SizedBox(height: 6),
                  Text(objective.summary),
                  const SizedBox(height: 6),
                  if (_eval != null)
                    Text(
                      '生成于 ${_fmt(_eval!.generatedAt)}'
                      '${_eval!.model == null ? '' : ' · ${_eval!.model}'}',
                      style: TextStyle(
                        color: theme.colorScheme.onSurfaceVariant,
                        fontSize: 12,
                      ),
                    ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _dimensionTile(BuildContext context, EvalDimension dim) {
    final theme = Theme.of(context);
    final color = _scoreColor(dim.score, theme.colorScheme);
    final expanded = _expanded.contains(dim.key);
    return InkWell(
      onTap: () => setState(() {
        if (expanded) {
          _expanded.remove(dim.key);
        } else {
          _expanded.add(dim.key);
        }
      }),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 10, 16, 10),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(child: Text(dim.label)),
                Text(
                  '${dim.score}',
                  style: theme.textTheme.titleMedium?.copyWith(color: color),
                ),
              ],
            ),
            const SizedBox(height: 6),
            ClipRRect(
              borderRadius: BorderRadius.circular(4),
              child: LinearProgressIndicator(
                value: dim.score / 100,
                minHeight: 8,
                backgroundColor: theme.colorScheme.surfaceContainerHighest,
                valueColor: AlwaysStoppedAnimation(color),
              ),
            ),
            const SizedBox(height: 6),
            Text(
              dim.comment,
              style: TextStyle(color: theme.colorScheme.onSurfaceVariant, fontSize: 12.5),
            ),
            if (expanded && dim.evidence.isNotEmpty) ...[
              const SizedBox(height: 8),
              Wrap(
                spacing: 6,
                runSpacing: 6,
                children: [
                  for (final e in dim.evidence)
                    Chip(
                      label: Text(e, style: const TextStyle(fontSize: 11)),
                      visualDensity: VisualDensity.compact,
                      materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                    ),
                ],
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _chipRow(BuildContext context, String title, List<String> items, Color color) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 40,
            child: Text(title, style: TextStyle(color: color, fontWeight: FontWeight.w600)),
          ),
          Expanded(
            child: items.isEmpty
                ? Text('—', style: TextStyle(color: theme.colorScheme.onSurfaceVariant))
                : Wrap(
                    spacing: 6,
                    runSpacing: 6,
                    children: [
                      for (final e in items)
                        Chip(
                          label: Text(e, style: const TextStyle(fontSize: 11)),
                          visualDensity: VisualDensity.compact,
                          materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                        ),
                    ],
                  ),
          ),
        ],
      ),
    );
  }

  // --- 通用组件 ---

  Widget _ring(ThemeData theme, int score, {required String label}) {
    final color = _scoreColor(score, theme.colorScheme);
    return SizedBox(
      width: 104,
      height: 104,
      child: Stack(
        alignment: Alignment.center,
        children: [
          SizedBox(
            width: 104,
            height: 104,
            child: CircularProgressIndicator(
              value: score / 100,
              strokeWidth: 9,
              backgroundColor: theme.colorScheme.surfaceContainerHighest,
              valueColor: AlwaysStoppedAnimation(color),
            ),
          ),
          Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                '$score',
                style: theme.textTheme.headlineMedium
                    ?.copyWith(color: color, fontWeight: FontWeight.bold),
              ),
              Text(label,
                  style: TextStyle(fontSize: 11, color: theme.colorScheme.onSurfaceVariant)),
            ],
          ),
        ],
      ),
    );
  }

  Widget _tag(ThemeData theme, String text, Color color) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.14),
          borderRadius: BorderRadius.circular(4),
        ),
        child: Text(text, style: TextStyle(fontSize: 11, color: color)),
      );

  Widget _section(
    BuildContext context, {
    required String title,
    required IconData icon,
    required List<Widget> children,
  }) {
    return Card(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 14, 16, 6),
            child: Row(
              children: [
                Icon(icon, size: 20, color: Theme.of(context).colorScheme.primary),
                const SizedBox(width: 8),
                Text(title, style: Theme.of(context).textTheme.titleMedium),
              ],
            ),
          ),
          const Divider(height: 1),
          ...children,
        ],
      ),
    );
  }

  static Color _scoreColor(int score, ColorScheme scheme) {
    if (score >= 80) return Colors.green.shade600;
    if (score >= 60) return Colors.orange.shade700;
    return scheme.error;
  }

  static Color _statusColor(String status, ColorScheme scheme) => switch (status) {
        'have' => Colors.green.shade600,
        'partial' => Colors.orange.shade700,
        'missing' => scheme.error,
        _ => scheme.outline,
      };

  static String _statusLabel(String status) => switch (status) {
        'have' => '已具备',
        'partial' => '部分满足',
        'missing' => '缺失',
        _ => '待确认',
      };

  static String _categoryLabel(String category) => switch (category) {
        'cert' => '证书',
        'experience' => '经历',
        'skill' => '技能',
        'education' => '教育',
        'portfolio' => '作品',
        _ => '其他',
      };

  static String _effortLabel(String effort) => switch (effort) {
        'low' => '低投入',
        'high' => '高投入',
        _ => '中投入',
      };

  static String _shortUrl(String url) {
    final noScheme = url.replaceFirst(RegExp(r'^https?://'), '');
    return noScheme.length > 28 ? '${noScheme.substring(0, 27)}…' : noScheme;
  }

  static String _fmt(DateTime t) =>
      '${t.year}-${t.month.toString().padLeft(2, '0')}-${t.day.toString().padLeft(2, '0')} '
      '${t.hour.toString().padLeft(2, '0')}:${t.minute.toString().padLeft(2, '0')}';
}
