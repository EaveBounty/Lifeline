/// 按简历 id 打开评估页（可寻址路由 `/resumes/eval/:id`，便于直达与测试）。
library;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/widgets/common.dart';
import '../../data/models/export_request.dart';
import '../../data/providers.dart';
import 'resume_eval_page.dart';

class ResumeEvalByIdPage extends ConsumerWidget {
  const ResumeEvalByIdPage({super.key, required this.id});

  final String id;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final lib = ref.watch(resumeLibraryProvider);
    return lib.when(
      loading: () => const Scaffold(body: LoadingView(message: '正在载入评估…')),
      error: (e, _) => Scaffold(body: ErrorView(error: e)),
      data: (list) {
        ResumeMeta? meta;
        for (final m in list) {
          if (m.id == id) {
            meta = m;
            break;
          }
        }
        if (meta == null) {
          return Scaffold(
            appBar: AppBar(title: const Text('简历评估')),
            body: const EmptyState(
              icon: Icons.search_off,
              title: '未找到该简历',
              message: '请先在简历库中生成定向简历。',
            ),
          );
        }
        return ResumeEvalPage(meta: meta);
      },
    );
  }
}
