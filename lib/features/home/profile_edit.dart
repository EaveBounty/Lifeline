/// 首页档案的内联编辑：姓名/联系方式/头衔/简介/亮点，写回 profile.json。
library;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/models/profile.dart';
import '../../data/models/profile_record.dart';
import '../../data/providers.dart';
import '../../services/ai/ai_config.dart';
import '../../services/ai/llm_client.dart';
import '../../services/profile/profile_summary_service.dart';

/// 基础信息字段：section / key / 标签 / 提示。
const List<(String, String, String, String)> _basicFields = [
  (ProfileSections.identity, 'name', '姓名', '如：张三'),
  (ProfileSections.identity, 'english_name', '英文名 / 拼音', '如：Zhang San'),
  (ProfileSections.identity, 'headline', '头衔 / 定位', '如：后端工程师（Go / K8s）'),
  (ProfileSections.contact, 'phone', '电话', '如：13800000000'),
  (ProfileSections.contact, 'email', '邮箱', '如：me@example.com'),
  (ProfileSections.contact, 'location', '所在地', '如：湖南长沙'),
  (ProfileSections.contact, 'website', '网站', 'https://…'),
  (ProfileSections.contact, 'github', 'GitHub', '用户名或链接'),
  (ProfileSections.contact, 'linkedin', 'LinkedIn', ''),
];

Future<void> editProfileBasics(BuildContext context, WidgetRef ref) async {
  final profile = ref.read(profileProvider).value;
  if (profile == null) return;
  final controllers = <(String, String, String), TextEditingController>{};
  for (final (section, key, _, _) in _basicFields) {
    controllers[(section, key, '')] = TextEditingController(
      text: profile.stringOf(section, key),
    );
  }

  final ok = await showDialog<bool>(
    context: context,
    builder: (ctx) => AlertDialog(
      title: const Text('编辑基本信息'),
      content: SizedBox(
        width: 460,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              for (final (section, key, label, hint) in _basicFields)
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 6),
                  child: TextField(
                    controller: controllers[(section, key, '')],
                    decoration: InputDecoration(
                      labelText: label,
                      hintText: hint.isEmpty ? null : hint,
                      border: const OutlineInputBorder(),
                      isDense: true,
                    ),
                  ),
                ),
            ],
          ),
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
    final notifier = ref.read(profileProvider.notifier);
    for (final (section, key, _, _) in _basicFields) {
      final text = controllers[(section, key, '')]!.text.trim();
      if (text != profile.stringOf(section, key)) {
        await notifier.setField(
          section,
          key,
          ProfileField(key: key, value: text),
        );
      }
    }
  }
  for (final c in controllers.values) {
    c.dispose();
  }
}

Future<void> editSummary(BuildContext context, WidgetRef ref) async {
  await _editTextSection(
    context,
    ref,
    title: '编辑个人简介',
    hint: '1-2 句：定位 + 最强证据',
    section: ProfileSections.summary,
    key: 'summary',
    initial: ref.read(profileProvider).value?.stringOf(
              ProfileSections.summary,
              'summary',
            ) ??
        '',
    multiline: true,
  );
}

Future<void> editStrengths(BuildContext context, WidgetRef ref) async {
  final strengths = ref.read(profileProvider).value?.valueOf(
        ProfileSections.strengths,
        'strengths',
      );
  final initial = strengths is List
      ? strengths.join('\n')
      : (strengths == null ? '' : '$strengths');
  await _editTextSection(
    context,
    ref,
    title: '编辑核心亮点',
    hint: '每行一条，如：第一作者发表 SCI 论文 3 篇',
    section: ProfileSections.strengths,
    key: 'strengths',
    initial: initial,
    multiline: true,
    asList: true,
  );
}

Future<void> _editTextSection(
  BuildContext context,
  WidgetRef ref, {
  required String title,
  required String hint,
  required String section,
  required String key,
  required String initial,
  bool multiline = false,
  bool asList = false,
}) async {
  final controller = TextEditingController(text: initial);
  final ok = await showDialog<bool>(
    context: context,
    builder: (ctx) => AlertDialog(
      title: Text(title),
      content: SizedBox(
        width: 520,
        child: TextField(
          controller: controller,
          autofocus: true,
          maxLines: multiline ? 6 : 1,
          minLines: multiline ? 3 : 1,
          decoration: InputDecoration(
            hintText: hint,
            border: const OutlineInputBorder(),
          ),
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
    final raw = controller.text.trim();
    final dynamic value = asList
        ? raw
            .split(RegExp(r'[\n]+'))
            .map((e) => e.trim())
            .where((e) => e.isNotEmpty)
            .toList()
        : raw;
    await ref
        .read(profileProvider.notifier)
        .setField(section, key, ProfileField(key: key, value: value));
  }
  controller.dispose();
}

/// 据全部素材重新生成简介与亮点（AI 优先，失败/未配置则本地确定性兜底）。
Future<void> regenerateSummary(BuildContext context, WidgetRef ref) async {
  final messenger = ScaffoldMessenger.of(context);
  final profile = ref.read(profileProvider).value;
  final records = ref.read(recordsProvider).value;
  if (profile == null || records == null) return;

  messenger.showSnackBar(const SnackBar(content: Text('正在据全部素材生成简介…')));
  final service = const ProfileSummaryService();
  ProfileHighlights? result;
  String? aiError;

  final settings = ref.read(settingsProvider).value;
  if (settings != null) {
    final cfg = await resolveAiCall(
      settings: settings,
      secrets: ref.read(secretStoreProvider),
    );
    if (cfg != null) {
      final res = await service.regenerate(
        profile: profile,
        records: records,
        llm: LlmClient(),
        baseUrl: cfg.baseUrl,
        apiKey: cfg.apiKey,
        model: cfg.model,
        extraHeaders: cfg.extraHeaders,
      );
      if (res.isOk) {
        result = res.valueOrNull;
      } else {
        aiError = res.errorMessage;
      }
    }
  }
  result ??= service.local(
    profile: profile,
    records: records,
    categories: ref.read(categoriesProvider),
  );

  final notifier = ref.read(profileProvider.notifier);
  await notifier.setField(
    ProfileSections.summary,
    'summary',
    ProfileField(
      key: 'summary',
      value: result.summary,
      source: const RecordSource(type: 'ai'),
    ),
  );
  await notifier.setField(
    ProfileSections.strengths,
    'strengths',
    ProfileField(
      key: 'strengths',
      value: result.strengths,
      source: const RecordSource(type: 'ai'),
    ),
  );
  messenger.showSnackBar(SnackBar(
    content: Text(aiError == null
        ? '已据全部素材更新简介与亮点'
        : 'AI 不可用（$aiError），已用本地汇总'),
  ));
}
