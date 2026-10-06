/// 跨功能复用的通用 UI 组件与工具。
library;

import 'package:flutter/material.dart';

import '../../data/models/record_category.dart';

/// 分类 -> 图标。
IconData categoryIcon(RecordCategory category) {
  switch (category) {
    case RecordCategory.education:
      return Icons.school_outlined;
    case RecordCategory.experience:
      return Icons.work_outline;
    case RecordCategory.projects:
      return Icons.account_tree_outlined;
    case RecordCategory.research:
      return Icons.science_outlined;
    case RecordCategory.awards:
      return Icons.emoji_events_outlined;
    case RecordCategory.publications:
      return Icons.menu_book_outlined;
    case RecordCategory.certificates:
      return Icons.verified_outlined;
    case RecordCategory.skills:
      return Icons.construction_outlined;
    case RecordCategory.languages:
      return Icons.translate_outlined;
    case RecordCategory.activities:
      return Icons.groups_outlined;
    case RecordCategory.trainings:
      return Icons.model_training_outlined;
    case RecordCategory.works:
      return Icons.palette_outlined;
    case RecordCategory.interests:
      return Icons.sports_esports_outlined;
    case RecordCategory.references:
      return Icons.contact_phone_outlined;
    case RecordCategory.custom:
      return Icons.category_outlined;
  }
}

/// 日期区间显示，自动处理「至今」。
String formatDateRange(String? start, String? end) {
  final s = (start ?? '').trim();
  final e = (end ?? '').trim();
  if (s.isEmpty && e.isEmpty) return '';
  if (s.isEmpty) return '至 $e';
  if (e.isEmpty) return '$s 至今';
  return '$s – $e';
}

/// 加载态。
class LoadingView extends StatelessWidget {
  const LoadingView({super.key, this.message});
  final String? message;
  @override
  Widget build(BuildContext context) => Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const CircularProgressIndicator(),
            if (message != null) ...[
              const SizedBox(height: 16),
              Text(message!, style: Theme.of(context).textTheme.bodyMedium),
            ],
          ],
        ),
      );
}

/// 错误态。
class ErrorView extends StatelessWidget {
  const ErrorView({super.key, required this.error, this.onRetry});
  final Object error;
  final VoidCallback? onRetry;
  @override
  Widget build(BuildContext context) => Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.error_outline,
                  color: Theme.of(context).colorScheme.error, size: 40),
              const SizedBox(height: 12),
              Text('$error', textAlign: TextAlign.center),
              if (onRetry != null) ...[
                const SizedBox(height: 16),
                FilledButton.tonal(onPressed: onRetry, child: const Text('重试')),
              ],
            ],
          ),
        ),
      );
}

/// 空态。
class EmptyState extends StatelessWidget {
  const EmptyState({
    super.key,
    required this.icon,
    required this.title,
    this.message,
    this.action,
  });
  final IconData icon;
  final String title;
  final String? message;
  final Widget? action;
  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 56, color: scheme.outline),
            const SizedBox(height: 16),
            Text(title, style: Theme.of(context).textTheme.titleMedium),
            if (message != null) ...[
              const SizedBox(height: 8),
              Text(message!,
                  textAlign: TextAlign.center,
                  style: TextStyle(color: scheme.onSurfaceVariant)),
            ],
            if (action != null) ...[const SizedBox(height: 20), action!],
          ],
        ),
      ),
    );
  }
}

/// 章节卡片。
class SectionCard extends StatelessWidget {
  const SectionCard({
    super.key,
    required this.title,
    this.icon,
    this.trailing,
    this.padding = const EdgeInsets.all(16),
    required this.child,
  });
  final String title;
  final IconData? icon;
  final Widget? trailing;
  final EdgeInsetsGeometry padding;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Card(
      child: Padding(
        padding: padding,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                if (icon != null) ...[
                  Icon(icon, size: 20, color: theme.colorScheme.primary),
                  const SizedBox(width: 8),
                ],
                Expanded(
                  child: Text(title, style: theme.textTheme.titleMedium),
                ),
                if (trailing != null) trailing!,
              ],
            ),
            const SizedBox(height: 12),
            child,
          ],
        ),
      ),
    );
  }
}

/// 标签 chip 组。
class TagChips extends StatelessWidget {
  const TagChips({super.key, required this.tags});
  final List<String> tags;
  @override
  Widget build(BuildContext context) {
    if (tags.isEmpty) return const SizedBox.shrink();
    return Wrap(
      spacing: 6,
      runSpacing: 6,
      children: tags
          .map((t) => Chip(
                label: Text(t, style: const TextStyle(fontSize: 12)),
                visualDensity: VisualDensity.compact,
                materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
              ))
          .toList(),
    );
  }
}
