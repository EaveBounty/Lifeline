/// 同步方式推荐与对比指南。
library;

import 'package:flutter/material.dart';

class SyncGuidePage extends StatelessWidget {
  const SyncGuidePage({super.key});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Scaffold(
      appBar: AppBar(title: const Text('同步方式指南')),
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 860),
          child: ListView(
            padding: const EdgeInsets.all(20),
            children: [
              Text(
                'Lifeline 不做同步，只读写您指定的文件夹。请在外部选择一种同步方式。'
                '由于数据是「一条记录一个 JSON 文件」的纯文本，对同步与版本管理都很友好。',
                style: TextStyle(
                    color: theme.colorScheme.onSurfaceVariant, height: 1.6),
              ),
              const SizedBox(height: 16),
              const _SyncCard(
                icon: Icons.devices,
                title: 'Syncthing（推荐 · 个人多设备）',
                pros: ['点对点、无需云账户', '跨 Android/Windows/Linux', '局域网/互联网自动中继'],
                cons: ['二进制数据库不适合 Git 场景', '两端同时编辑同一文件可能产生冲突副本'],
                steps: [
                  '在所有设备安装 Syncthing 并互相添加设备。',
                  '把 Lifeline 同步根文件夹添加为共享文件夹。',
                  '保持两端在线即自动增量同步。',
                  '冲突时 Lifeline 会保留 .conflict 副本，可手动合并。',
                ],
              ),
              const SizedBox(height: 12),
              const _SyncCard(
                icon: Icons.cloud,
                title: 'WebDAV（自建/网盘）',
                pros: ['可用坚果云、Nextcloud 等', '移动端支持好'],
                cons: ['依赖第三方网盘容量与限速', '部分网盘对大量小文件不友好'],
                steps: [
                  '在网盘/自建服务开启 WebDAV。',
                  '用支持 WebDAV 的同步客户端把同步根映射到云端。',
                  '各设备通过同一客户端同步。',
                ],
              ),
              const SizedBox(height: 12),
              const _SyncCard(
                icon: Icons.history_edu,
                title: 'Git（推荐 · 重视版本历史）',
                pros: ['完整历史与回滚', 'JSON 文本可 diff/合并', '可托管到私有仓库'],
                cons: ['二进制附件仓库会变大', '需要一点命令行/客户端知识'],
                steps: [
                  '在同步根执行 git init 并添加 .gitignore（忽略 data/index.sqlite）。',
                  '提交数据目录与附件。',
                  '各设备 pull/push；冲突用分支解决。',
                  '建议用私有仓库，注意个人信息与附件隐私。',
                ],
              ),
              const SizedBox(height: 20),
              Card(
                color: theme.colorScheme.errorContainer,
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Icon(Icons.warning_amber_rounded),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Text(
                          '隐私提示：简历包含身份证号、联系方式等敏感信息。'
                          '使用第三方云同步/托管前请评估风险，必要时加密或仅用可信的私有渠道。',
                          style: TextStyle(
                              color: theme.colorScheme.onErrorContainer,
                              height: 1.5),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _SyncCard extends StatelessWidget {
  const _SyncCard({
    required this.icon,
    required this.title,
    required this.pros,
    required this.cons,
    required this.steps,
  });
  final IconData icon;
  final String title;
  final List<String> pros;
  final List<String> cons;
  final List<String> steps;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(icon, color: scheme.primary),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(title,
                      style: Theme.of(context).textTheme.titleMedium),
                ),
              ],
            ),
            const SizedBox(height: 10),
            _prosCons('优点', pros, Icons.add_circle_outline, scheme.primary),
            const SizedBox(height: 6),
            _prosCons('注意', cons, Icons.remove_circle_outline,
                scheme.onSurfaceVariant),
            const SizedBox(height: 10),
            Text('配置步骤', style: Theme.of(context).textTheme.labelLarge),
            const SizedBox(height: 4),
            ...steps.asMap().entries.map((e) => Padding(
                  padding: const EdgeInsets.symmetric(vertical: 2),
                  child: Text('${e.key + 1}. ${e.value}',
                      style: const TextStyle(height: 1.4)),
                )),
          ],
        ),
      ),
    );
  }

  Widget _prosCons(
      String label, List<String> items, IconData icon, Color color) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: items
          .map((t) => Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Padding(
                    padding: const EdgeInsets.only(top: 3),
                    child: Icon(icon, size: 15, color: color),
                  ),
                  const SizedBox(width: 6),
                  Expanded(child: Text(t, style: const TextStyle(height: 1.35))),
                ],
              ))
          .toList(),
    );
  }
}
