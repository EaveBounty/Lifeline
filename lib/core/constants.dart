/// Lifeline 全局常量与磁盘约定。
///
/// 所有目录/文件名在此集中定义，禁止在别处硬编码字符串。
library;

/// 应用标识。
class AppInfo {
  static const String nameEn = 'Lifeline';
  static const String nameZh = '履痕';
  static const String tagline = '个人资料管理 · 自动编译简历';
  static const String authorZh = '长沙市果垂素宇工程设计有限公司';
  static const String authorEn = 'EaveBounty';
  static const int schemaVersion = 1;
}

/// 同步根目录内的文件/文件夹名。
class SyncLayout {
  /// 设置文件（YAML，无密钥，可安全同步）。
  static const String configFile = 'lifeline.yaml';

  /// 密钥降级文件名（B6）。
  ///
  /// 位于 **App 支持目录**（`getApplicationSupportDirectory()`），不在同步根内、
  /// 默认不同步；仅在系统密钥库不可用时启用。唯一事实来源见 [SecretStore]。
  static const String secretsFile = 'secrets.local.json';

  /// 数据根目录。
  static const String dataDir = 'data';

  /// 单例 profile。
  static const String profileFile = 'profile.json';

  /// 记录目录（下分 category 子目录）。
  static const String recordsDir = 'records';

  /// 派生索引。
  static const String indexFile = 'index.sqlite';

  /// 定向简历产物目录。
  static const String resumesDir = 'resumes';

  /// 附件目录。
  static const String attachmentsDir = 'attachments';

  /// 内部状态目录。
  static const String internalDir = '.lifeline';

  /// 内部状态文件。
  static const String stateFile = 'state.json';

  /// 冲突副本后缀（多端并发写时保留）。
  static const String conflictSuffix = '.conflict';
}

/// 附件 MIME 与分组。
class AttachmentTypes {
  static const List<String> imageExts = [
    'jpg', 'jpeg', 'png', 'gif', 'webp', 'bmp', 'heic',
  ];
  static const List<String> docExts = [
    'pdf', 'doc', 'docx', 'xls', 'xlsx', 'ppt', 'pptx', 'txt', 'md',
  ];
  static const List<String> allExts = [...imageExts, ...docExts];

  static bool isImage(String path) =>
      imageExts.contains(path.split('.').last.toLowerCase());
}
