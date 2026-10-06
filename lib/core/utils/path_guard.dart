/// 路径安全护栏：防止来自磁盘/同步内容的 id 与相对路径越界。
///
/// 约束：id 仅允许 `[A-Za-z0-9._-]` 且不含 `..`；相对路径规范化后必须
/// 仍位于同步根之内。越界一律返回 null 或抛出受控 [ArgumentError]。
library;

import 'package:path/path.dart' as p;

final RegExp _idPattern = RegExp(r'^[A-Za-z0-9._-]+$');

/// id 白名单校验（record id / resume id / 附件 id）。
bool isSafeId(String id) {
  if (id.isEmpty) return false;
  if (!_idPattern.hasMatch(id)) return false;
  if (id.contains('..')) return false;
  return true;
}

/// 将 [rel] 相对 [root] 解析为绝对路径；越界或绝对路径返回 null。
///
/// 统一按 `/` 归一化后比较前缀，拒绝 `../` 逃逸与绝对路径注入。
String? resolveWithinRoot(String root, String rel) {
  if (rel.trim().isEmpty) return null;
  final normalizedRel = p.normalize(rel.replaceAll(r'\', '/'));
  if (p.isAbsolute(normalizedRel)) return null;
  final rootAbs = p.normalize(p.absolute(root));
  final joined = p.normalize(p.join(rootAbs, normalizedRel));
  final rootWithSep =
      rootAbs.endsWith(p.separator) ? rootAbs : '$rootAbs${p.separator}';
  if (joined == rootAbs || joined.startsWith(rootWithSep)) return joined;
  return null;
}
