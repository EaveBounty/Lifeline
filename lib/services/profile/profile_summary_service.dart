/// 个人简介 / 核心亮点：据全部素材生成。
///
/// - AI 通道：`profileSummarySystemPrompt` → 严格 JSON；
/// - 本地确定性兜底：素材不可用/模型失败时按分类计数汇总。
library;

import 'dart:convert';

import '../../core/result.dart';
import '../../data/models/profile.dart';
import '../../data/models/profile_record.dart';
import '../../data/models/record_category.dart';
import '../ai/llm_client.dart';
import '../ai/prompts.dart';

typedef ProfileHighlights = ({String summary, List<String> strengths});

class ProfileSummaryService {
  const ProfileSummaryService();

  Future<Result<ProfileHighlights>> regenerate({
    required Profile profile,
    required List<ProfileRecord> records,
    required LlmClient llm,
    required String baseUrl,
    required String apiKey,
    required String model,
    Map<String, String> extraHeaders = const {},
  }) async {
    try {
      final res = await llm.chatCompletion(
        baseUrl: baseUrl,
        apiKey: apiKey,
        model: model,
        messages: [
          LlmMessage.text('system', profileSummarySystemPrompt),
          LlmMessage.text('user', _payload(profile, records)),
        ],
        jsonMode: true,
        extraHeaders: extraHeaders,
      );
      if (res.isErr) return Err(res.errorMessage!);
      final raw = res.valueOrNull!;
      final json = extractJsonBlock(raw).trim().isEmpty
          ? raw
          : extractJsonBlock(raw);
      final map = jsonDecode(json) as Map<String, dynamic>;
      final summary = '${map['summary'] ?? ''}'.trim();
      final strengths = (map['strengths'] as List?)
              ?.map((e) => '$e'.trim())
              .where((e) => e.isNotEmpty)
              .toList() ??
          const <String>[];
      if (summary.isEmpty && strengths.isEmpty) {
        return const Err('模型未返回有效的简介/亮点');
      }
      return Ok((summary: summary, strengths: strengths));
    } catch (e) {
      return Err('生成简介失败: $e', e);
    }
  }

  /// 本地确定性兜底（不调用 AI）。
  ProfileHighlights local({
    required Profile profile,
    required List<ProfileRecord> records,
    List<CategoryDef> categories = kDefaultCategories,
  }) {
    final active = records.where((r) => r.status == 'active').toList();
    final counts = <String, int>{};
    for (final r in active) {
      counts[r.categorySlug] = (counts[r.categorySlug] ?? 0) + 1;
    }
    String label(String slug) => resolveCategory(categories, slug).label;
    final top = counts.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));

    final name = profile.stringOf(ProfileSections.identity, 'name');
    final headline = profile.stringOf(ProfileSections.identity, 'headline');
    final head = [name, headline].where((e) => e.trim().isNotEmpty).join(' · ');
    final parts = <String>[
      if (head.isNotEmpty) head,
      '共整理 ${active.length} 条经历',
      if (top.isNotEmpty)
        '涵盖 ${top.take(3).map((e) => '${label(e.key)} ${e.value} 项').join('、')}',
    ];
    return (
      summary: '${parts.join('，')}。',
      strengths: [
        for (final e in top.take(4)) '${label(e.key)}：${e.value} 项',
      ],
    );
  }

  String _payload(Profile profile, List<ProfileRecord> records) {
    final b = StringBuffer();
    b.writeln('【身份】'
        '${profile.stringOf(ProfileSections.identity, 'name')} / '
        '${profile.stringOf(ProfileSections.identity, 'headline')}');
    final cur = profile.stringOf(ProfileSections.summary, 'summary');
    if (cur.isNotEmpty) b.writeln('【现有简介（可改写）】$cur');
    b.writeln('【全部素材摘要】');
    for (final r in records) {
      if (r.status != 'active') continue;
      final dates = [
        if ((r.startDate ?? '').isNotEmpty) r.startDate!,
        if ((r.endDate ?? '').isNotEmpty) r.endDate!,
      ].join('~');
      final bits = [
        if (dates.isNotEmpty) dates,
        r.title,
        if ((r.organization ?? '').isNotEmpty) '@${r.organization}',
        if ((r.role ?? '').isNotEmpty) r.role!,
        if (r.highlights.isNotEmpty) r.highlights.join('；'),
      ].where((e) => e.trim().isNotEmpty).join(' | ');
      b.writeln('- ${_clip(bits, 160)}');
    }
    return b.toString();
  }

  static String _clip(String s, int max) =>
      s.length <= max ? s : '${s.substring(0, max)}…';
}
