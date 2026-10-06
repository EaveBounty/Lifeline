/// Web 演示种子：向当前同步根写入示例 profile / 记录 / 定向简历。
///
/// 仅用于浏览器端到端测试与截图（`?demo=1`）。写入的都是内存文件系统，
/// 刷新即清空，不触碰任何真实数据；id 固定，重复调用为幂等覆盖。
library;

import 'dart:convert';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../data/models/export_request.dart';
import '../data/models/profile.dart';
import '../data/models/profile_record.dart';
import '../data/models/record_category.dart';
import '../data/providers.dart';
import '../data/repositories/profile_repository.dart';
import '../data/repositories/records_repository.dart';
import '../data/repositories/resume_repository.dart';
import '../services/ai/llm_client.dart';
import '../services/compile/resume_compiler.dart';
import '../services/export/resume_eval_service.dart';

/// 示例简历 id（固定）。
const String kDemoResumeId = 'demo-resume-0001';

/// 向当前同步根写入演示数据；未挂载根时静默返回。
Future<void> seedDemo(ProviderContainer container) async {
  final path = container.read(syncRootProvider).path;
  if (path == null) return;
  final db = container.read(databaseProvider);
  if (db == null) return;

  final now = DateTime.now();
  final profile = _profile(now);
  final records = _records(now);

  await ProfileRepository(path).save(profile);
  final recordsRepo = RecordsRepository(rootPath: path, db: db);
  for (final record in records) {
    await recordsRepo.save(record);
  }

  final doc = const ResumeCompiler().compile(
    profile: profile,
    records: records,
    language: 'zh',
  );
  final request = _request();
  final evaluation = ResumeEvalService(llm: LlmClient())
      .evaluateHeuristic(doc: doc, request: request);

  final meta = ResumeMeta(
    id: kDemoResumeId,
    name: '后端工程师 · 示例科技',
    targetRole: '后端工程师',
    targetCompany: '示例科技有限公司',
    purpose: '求职',
    requirements: '突出高并发、性能优化与云原生经验；一页以内。',
    status: 'generated',
    files: {'md': 'data/resumes/$kDemoResumeId/resume.md'},
    request: request,
    evaluation: evaluation,
    createdAt: now,
    updatedAt: now,
    notes: '演示数据：由 demo 种子生成。',
  );

  final repo = ResumeRepository(path);
  await repo.saveMeta(meta);
  await repo.saveSpec(meta.id, doc);
  await repo.saveFile(
    meta.id,
    'md',
    utf8.encode('# 林知微 · 后端工程师\n\n> 演示用定向简历（Markdown 产物）。\n'),
  );
}

ExportRequest _request() => const ExportRequest(
      purpose: '求职',
      targetRole: '后端工程师',
      targetCompany: '示例科技有限公司',
      industry: '互联网',
      pageLimit: 1,
      language: 'zh',
      style: 'concise',
      tone: 'professional',
      emphasis: '高并发与稳定性',
      mustInclude: ['Go', 'MySQL', 'Redis', 'Kubernetes'],
      exclude: ['读书感想'],
      researchEnabled: true,
      extraNotes: '面向互联网大厂后端岗位。',
    );

Profile _profile(DateTime now) => Profile(
      updatedAt: now,
      sections: {
        ProfileSections.identity: {
          'name': const ProfileField(key: 'name', value: '林知微'),
          'english_name':
              const ProfileField(key: 'english_name', value: 'Zhiwei Lin'),
          'headline': const ProfileField(
            key: 'headline',
            value: '后端开发工程师 · 高并发系统',
          ),
        },
        ProfileSections.contact: {
          'email': const ProfileField(
            key: 'email',
            value: 'linzhiwei@example.com',
          ),
          'phone': const ProfileField(key: 'phone', value: '138-0000-0000'),
          'location': const ProfileField(key: 'location', value: '上海'),
          'github': const ProfileField(
            key: 'github',
            value: 'github.com/linzhiwei',
          ),
          'website': const ProfileField(
            key: 'website',
            value: 'linzhiwei.dev',
          ),
        },
        ProfileSections.summary: {
          'summary': const ProfileField(
            key: 'summary',
            value: '5 年高并发后端开发经验，专注订单与交易系统的服务治理、'
                '性能优化与稳定性建设。主导过 QPS 从千级到万级的架构演进，'
                '擅长用数据驱动的方式定位并解决系统瓶颈。',
          ),
        },
        ProfileSections.strengths: {
          'strengths': const ProfileField(
            key: 'strengths',
            value: [
              '主导核心服务重构，QPS 提升 4 倍',
              '精通 Go / MySQL / Redis / Kubernetes 技术栈',
              '具备从 0 到 1 搭建可观测体系与稳定性预案的实战经验',
            ],
          ),
        },
      },
    );

List<ProfileRecord> _records(DateTime now) => [
      ProfileRecord(
        id: 'demo-edu-0001',
        category: RecordCategory.education,
        title: '示例大学 · 计算机科学与技术',
        organization: '示例大学',
        role: '本科',
        location: '杭州',
        startDate: '2018-09',
        endDate: '2022-06',
        description: '主修计算机科学与技术，方向为分布式系统。',
        highlights: const ['GPA 3.8/4.0（专业前 5%）', '两次获得校级一等奖学金'],
        tags: const ['计算机', '本科'],
        fields: const {'major': '计算机科学与技术', 'gpa': '3.8/4.0'},
        createdAt: now,
        updatedAt: now,
        order: 0,
      ),
      ProfileRecord(
        id: 'demo-exp-0001',
        category: RecordCategory.experience,
        title: '后端开发工程师',
        organization: '示例科技有限公司',
        role: '后端开发工程师',
        location: '上海',
        startDate: '2022-07',
        description: '负责订单与交易域的后端服务设计与研发。',
        highlights: const [
          '主导订单服务重构，QPS 从 800 提升至 3500',
          '将接口平均延迟从 320ms 降至 90ms，降低 72%',
          '设计并落地分库分表方案，支撑日均 2000 万订单',
        ],
        tags: const ['Go', 'MySQL', 'Redis'],
        fields: const {'team_size': '8'},
        createdAt: now,
        updatedAt: now,
        order: 0,
      ),
      ProfileRecord(
        id: 'demo-prj-0001',
        category: RecordCategory.projects,
        title: 'Lifeline 个人资料管理',
        role: '独立开发',
        startDate: '2024-01',
        description: '跨平台个人资料管理工具，数据以纯文本挂载于用户同步根。',
        highlights: const [
          '纯文本真相源 + 可重建索引，支持多端同步',
          'Flutter 四平台，核心链路具备端到端测试覆盖',
        ],
        tags: const ['Flutter', 'Dart'],
        createdAt: now,
        updatedAt: now,
        order: 0,
      ),
      ProfileRecord(
        id: 'demo-award-0001',
        category: RecordCategory.awards,
        title: '全国大学生软件设计大赛 一等奖',
        organization: '教育部',
        startDate: '2021-10',
        highlights: const ['团队 3 人，负责后端架构与性能优化'],
        tags: const ['竞赛'],
        createdAt: now,
        updatedAt: now,
        order: 0,
      ),
      ProfileRecord(
        id: 'demo-skill-0001',
        category: RecordCategory.skills,
        title: '后端与云原生技术栈',
        highlights: const [
          '语言：Go / Java / Python / SQL',
          '中间件：MySQL / Redis / Kafka / Elasticsearch',
          '云原生：Docker / Kubernetes / Prometheus',
        ],
        tags: const ['后端', '云原生'],
        createdAt: now,
        updatedAt: now,
        order: 0,
      ),
    ];
