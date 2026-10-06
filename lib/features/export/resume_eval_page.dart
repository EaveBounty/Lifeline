/// 简历多角度评估页：总分 / 维度 / 缺漏 / 按边际效益排序的改进建议。
library;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../data/models/ai_provider.dart';
import '../../data/models/export_request.dart';
import '../../data/models/resume_doc.dart';
import '../../data/models/resume_eval.dart';
import '../../data/providers.dart';
import '../../data/repositories/resume_repository.dart';
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
  String? _error;
  final Set<String> _expanded = {};

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
        constraints: const BoxConstraints(maxWidth: 820),
        child: ListView(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 32),
          children: [
            _aiButton(context, providers),
            const SizedBox(height: 12),
            _scoreHeader(context, eval),
            const SizedBox(height: 12),
            _section(
              context,
              title: '维度评分',
              icon: Icons.radar,
              children: [for (final d in eval.dimensions) _dimensionTile(context, d)],
            ),
            const SizedBox(height: 12),
            _section(
              context,
              title: '缺漏项（${eval.missing.length}）',
              icon: Icons.report_problem_outlined,
              children: eval.missing.isEmpty
                  ? [const ListTile(dense: true, title: Text('未发现明显缺漏。'))]
                  : [for (final m in eval.missing) _missingTile(context, m)],
            ),
            const SizedBox(height: 12),
            _section(
              context,
              title: '改进建议（按边际效益排序）',
              icon: Icons.trending_up,
              children: [
                for (final r in eval.recommendations) _recTile(context, r),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _aiButton(BuildContext context, List<AiProvider> providers) {
    final enabled = providers.isNotEmpty && _doc != null && !_aiRunning;
    final button = FilledButton.icon(
      onPressed: enabled ? _runAi : null,
      icon: _aiRunning
          ? const SizedBox(
              width: 18,
              height: 18,
              child: CircularProgressIndicator(strokeWidth: 2),
            )
          : const Icon(Icons.auto_awesome),
      label: Text(_aiRunning ? 'AI 评估中…' : 'AI 评估'),
    );
    if (providers.isEmpty) {
      return Tooltip(
        message: '未配置 AI Provider，请前往「设置 → AI」',
        child: button,
      );
    }
    return Align(alignment: Alignment.centerRight, child: button);
  }

  Widget _scoreHeader(BuildContext context, ResumeEvaluation eval) {
    final theme = Theme.of(context);
    final color = _scoreColor(eval.overall, theme.colorScheme);
    final subtitle = [eval.targetRole, eval.targetCompany]
        .where((e) => e != null && e.trim().isNotEmpty)
        .join(' · ');
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            SizedBox(
              width: 104,
              height: 104,
              child: Stack(
                alignment: Alignment.center,
                children: [
                  SizedBox(
                    width: 104,
                    height: 104,
                    child: CircularProgressIndicator(
                      value: eval.overall / 100,
                      strokeWidth: 9,
                      backgroundColor: theme.colorScheme.surfaceContainerHighest,
                      valueColor: AlwaysStoppedAnimation(color),
                    ),
                  ),
                  Text(
                    '${eval.overall}',
                    style: theme.textTheme.headlineMedium
                        ?.copyWith(color: color, fontWeight: FontWeight.bold),
                  ),
                ],
              ),
            ),
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
                          eval.aiAssisted ? 'AI 评估' : '启发式',
                          style: const TextStyle(fontSize: 11),
                        ),
                        visualDensity: VisualDensity.compact,
                        materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                      ),
                    ],
                  ),
                  if (subtitle.isNotEmpty)
                    Text(subtitle, style: TextStyle(color: theme.colorScheme.onSurfaceVariant)),
                  const SizedBox(height: 8),
                  Text(eval.summary),
                  const SizedBox(height: 4),
                  Text(
                    '生成于 ${_fmt(eval.generatedAt)}'
                    '${eval.model == null ? '' : ' · ${eval.model}'}',
                    style: TextStyle(color: theme.colorScheme.onSurfaceVariant, fontSize: 12),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

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

  Widget _missingTile(BuildContext context, EvalMissingItem m) {
    final theme = Theme.of(context);
    final color = _severityColor(m.severity, theme.colorScheme);
    return ListTile(
      dense: true,
      leading: Icon(Icons.circle, size: 12, color: color),
      title: Row(
        children: [
          Expanded(child: Text(m.item)),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.15),
              borderRadius: BorderRadius.circular(4),
            ),
            child: Text(
              _severityLabel(m.severity),
              style: TextStyle(fontSize: 11, color: color),
            ),
          ),
        ],
      ),
      subtitle: Text('${m.why}\n建议：${m.suggestion}'),
      isThreeLine: true,
    );
  }

  Widget _recTile(BuildContext context, EvalRecommendation r) {
    final theme = Theme.of(context);
    return ListTile(
      dense: true,
      leading: CircleAvatar(
        radius: 14,
        backgroundColor: theme.colorScheme.primaryContainer,
        child: Text(
          '${r.priority}',
          style: TextStyle(fontSize: 12, color: theme.colorScheme.onPrimaryContainer),
        ),
      ),
      title: Text(r.item),
      subtitle: Text(r.rationale),
      trailing: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          Text(
            '+${r.expectedGain}',
            style: TextStyle(color: theme.colorScheme.primary, fontWeight: FontWeight.bold),
          ),
          Text(
            _effortLabel(r.effort),
            style: TextStyle(fontSize: 11, color: theme.colorScheme.onSurfaceVariant),
          ),
        ],
      ),
    );
  }

  static Color _scoreColor(int score, ColorScheme scheme) {
    if (score >= 80) return Colors.green.shade600;
    if (score >= 60) return Colors.orange.shade700;
    return scheme.error;
  }

  static Color _severityColor(String severity, ColorScheme scheme) => switch (severity) {
        'high' => scheme.error,
        'low' => scheme.outline,
        _ => Colors.orange.shade700,
      };

  static String _severityLabel(String severity) => switch (severity) {
        'high' => '高',
        'low' => '低',
        _ => '中',
      };

  static String _effortLabel(String effort) => switch (effort) {
        'low' => '低投入',
        'high' => '高投入',
        _ => '中投入',
      };

  static String _fmt(DateTime t) =>
      '${t.year}-${t.month.toString().padLeft(2, '0')}-${t.day.toString().padLeft(2, '0')} '
      '${t.hour.toString().padLeft(2, '0')}:${t.minute.toString().padLeft(2, '0')}';
}
