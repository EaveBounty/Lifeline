/// 跨功能复用的通用 UI 组件与工具。
library;

import 'package:flutter/material.dart';

/// 图标键 -> IconData 目录（分类图标可编辑；未知键回退 [_defaultIcon]）。
const Map<String, IconData> kCategoryIcons = {
  'school': Icons.school_outlined,
  'work': Icons.work_outline,
  'account_tree': Icons.account_tree_outlined,
  'science': Icons.science_outlined,
  'emoji_events': Icons.emoji_events_outlined,
  'menu_book': Icons.menu_book_outlined,
  'verified': Icons.verified_outlined,
  'construction': Icons.construction_outlined,
  'translate': Icons.translate_outlined,
  'groups': Icons.groups_outlined,
  'model_training': Icons.model_training_outlined,
  'palette': Icons.palette_outlined,
  'sports_esports': Icons.sports_esports_outlined,
  'contact_phone': Icons.contact_phone_outlined,
  'category': Icons.category_outlined,
  'star': Icons.star_outline,
  'code': Icons.code_outlined,
  'business_center': Icons.business_center_outlined,
  'public': Icons.public_outlined,
  'favorite': Icons.favorite_outline,
  'home': Icons.home_outlined,
  'lightbulb': Icons.lightbulb_outline,
  'rocket_launch': Icons.rocket_launch_outlined,
  'campaign': Icons.campaign_outlined,
  'apps': Icons.apps_outlined,
  'bookmark': Icons.bookmark_outline,
  'directions_run': Icons.directions_run_outlined,
  'brush': Icons.brush_outlined,
  'computer': Icons.computer_outlined,
  'psychology': Icons.psychology_outlined,
  'military_tech': Icons.military_tech_outlined,
  'volunteer_activism': Icons.volunteer_activism_outlined,
  'attach_money': Icons.attach_money_outlined,
  'handshake': Icons.handshake_outlined,
};

const IconData _defaultIcon = Icons.category_outlined;

/// 图标键 -> 图标；未知键回退默认。
IconData categoryIcon(String? iconKey) =>
    kCategoryIcons[iconKey] ?? _defaultIcon;

/// 供图标选择器使用的有序键列表。
List<String> get categoryIconKeys => kCategoryIcons.keys.toList();

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
