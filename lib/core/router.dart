/// 路由表（go_router）。根状态为空时由 app.dart 显示首启页，故此处无需 redirect。
library;

import 'package:go_router/go_router.dart';

import '../data/models/export_request.dart';
import '../features/ai/capture_page.dart';
import '../features/attachments/attachments_page.dart';
import '../features/export/export_page.dart';
import '../features/export/resume_eval_page.dart';
import '../features/export/resume_eval_route.dart';
import '../features/export/resume_manager_page.dart';
import '../features/home/full_resume_page.dart';
import '../features/onboarding/sync_guide_page.dart';
import '../features/records/record_detail_page.dart';
import '../features/records/record_edit_page.dart';
import '../features/records/records_page.dart';
import '../features/settings/ai_settings_page.dart';
import '../features/settings/categories_page.dart';
import '../features/settings/secret_vault_page.dart';
import '../features/settings/settings_page.dart';

final GoRouter appRouter = GoRouter(
  initialLocation: '/',
  routes: [
    GoRoute(path: '/', builder: (_, __) => const FullResumePage()),
    GoRoute(path: '/sync', builder: (_, __) => const SyncGuidePage()),
    GoRoute(path: '/records', builder: (_, __) => const RecordsPage()),
    GoRoute(path: '/records/new', builder: (_, __) => const RecordEditPage()),
    GoRoute(
      path: '/records/:id',
      builder: (_, s) =>
          RecordDetailPage(recordId: s.pathParameters['id']!),
    ),
    GoRoute(
      path: '/records/:id/edit',
      builder: (_, s) =>
          RecordEditPage(recordId: s.pathParameters['id']!),
    ),
    GoRoute(path: '/attachments', builder: (_, __) => const AttachmentsPage()),
    GoRoute(path: '/settings', builder: (_, __) => const SettingsPage()),
    GoRoute(path: '/settings/ai', builder: (_, __) => const AiSettingsPage()),
    GoRoute(
      path: '/settings/categories',
      builder: (_, __) => const CategoriesPage(),
    ),
    GoRoute(
      path: '/settings/vault',
      builder: (_, __) => const SecretVaultPage(),
    ),
    GoRoute(path: '/capture', builder: (_, __) => const CapturePage()),
    GoRoute(path: '/export', builder: (_, __) => const ExportPage()),
    GoRoute(path: '/resumes', builder: (_, __) => const ResumeManagerPage()),
    GoRoute(
      path: '/resumes/eval',
      builder: (_, s) {
        final meta = s.extra;
        if (meta is! ResumeMeta) return const ResumeManagerPage();
        return ResumeEvalPage(meta: meta);
      },
    ),
    GoRoute(
      path: '/resumes/eval/:id',
      builder: (_, s) => ResumeEvalByIdPage(id: s.pathParameters['id']!),
    ),
  ],
);
