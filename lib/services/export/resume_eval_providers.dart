/// 简历评估服务 Provider：随设置/密钥变化重建。
library;

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/providers.dart';
import '../ai/llm_client.dart';
import 'resume_eval_service.dart';

final resumeEvalServiceProvider = Provider<ResumeEvalService>((ref) {
  ref.watch(secretStoreProvider);
  ref.watch(settingsProvider);
  return ResumeEvalService(llm: LlmClient());
});
