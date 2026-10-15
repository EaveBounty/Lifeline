/// 导出数据：把档案与全部记录导出为干净 YAML 文本，便于复制/再编辑。
library;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:path/path.dart' as p;

import '../../core/constants.dart';
import '../../core/utils/file_utils.dart';
import '../../core/widgets/common.dart';
import '../../data/providers.dart';
import '../../services/export/data_exporter.dart';

class DataExportPage extends ConsumerStatefulWidget {
  const DataExportPage({super.key});

  @override
  ConsumerState<DataExportPage> createState() => _DataExportPageState();
}

class _DataExportPageState extends ConsumerState<DataExportPage> {
  String _yaml = '';
  bool _busy = true;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _build());
  }

  Future<void> _build() async {
    final profile = await ref.read(profileProvider.future);
    final records = await ref.read(recordsProvider.future);
    if (!mounted) return;
    setState(() {
      _yaml = const DataExporter().build(profile: profile, records: records);
      _busy = false;
    });
  }

  void _snack(String s) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(s)));
  }

  Future<void> _copy() async {
    await Clipboard.setData(ClipboardData(text: _yaml));
    _snack('已复制全部内容到剪贴板');
  }

  Future<void> _save() async {
    final root = ref.read(syncRootProvider).path;
    if (root == null) {
      _snack('尚未挂载同步根');
      return;
    }
    final now = DateTime.now();
    final stamp = '${now.year}${now.month.toString().padLeft(2, '0')}'
        '${now.day.toString().padLeft(2, '0')}-${now.hour.toString().padLeft(2, '0')}'
        '${now.minute.toString().padLeft(2, '0')}${now.second.toString().padLeft(2, '0')}';
    final dir = p.join(root, SyncLayout.dataDir, 'exports');
    final path = p.join(dir, 'lifeline-data-$stamp.yaml');
    try {
      await ensureDir(dir);
      await writeStringAtomic(path, _yaml);
      _snack('已保存：$path');
    } catch (e) {
      _snack('保存失败：$e');
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Scaffold(
      appBar: AppBar(
        title: const Text('导出数据'),
        actions: [
          IconButton(
            tooltip: '复制全部',
            icon: const Icon(Icons.copy_all),
            onPressed: _busy ? null : _copy,
          ),
          IconButton(
            tooltip: '保存到同步根',
            icon: const Icon(Icons.save_alt),
            onPressed: _busy ? null : _save,
          ),
        ],
      ),
      body: _busy
          ? const LoadingView(message: '正在整理数据…')
          : Center(
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 920),
                child: ListView(
                  padding: const EdgeInsets.fromLTRB(16, 12, 16, 32),
                  children: [
                    SectionCard(
                      title: '说明',
                      icon: Icons.info_outline,
                      child: Text(
                        '下面是你的全部档案与经历，已整理成干净的 YAML：一行一条经历（年月 + 事件），'
                        '不含软件自带的分类与标签。可直接「复制全部」粘贴到别处编辑，或保存为文件。',
                        style: TextStyle(
                          color: theme.colorScheme.onSurfaceVariant,
                          height: 1.5,
                        ),
                      ),
                    ),
                    const SizedBox(height: 12),
                    Card(
                      child: Padding(
                        padding: const EdgeInsets.all(12),
                        child: SelectableText(
                          _yaml,
                          style: const TextStyle(
                            fontFamily: 'monospace',
                            fontSize: 12.5,
                            height: 1.5,
                          ),
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
