/// 密钥清洗与校验。
///
/// 直接把手输/粘贴的内容塞进 `Authorization: Bearer <key>` 时，若含换行、
/// 中文或不可见字符，`dart:io` 会抛
/// `FormatException: Invalid HTTP header field value`（表现为「未知网络错误」）。
library;

/// 去掉首尾空白与所有换行/制表/控制字符（粘贴常见污染）。
String sanitizeSecret(String raw) =>
    raw.replaceAll(RegExp(r'[\u0000-\u001f\u007f]'), '').trim();

/// 校验是否为可用的密钥。返回 null 表示可用；空串表示「不发送」，也算可用。
String? validateSecret(String value) {
  if (value.isEmpty) return null;
  if (RegExp(r'[^\x21-\x7e]').hasMatch(value)) {
    return 'API Key 含空白、换行、中文或不可见字符，请只粘贴形如 sk-… 的密钥';
  }
  return null;
}

/// 脱敏预览：保留首尾少量字符，中间以 … 代替。
String maskSecret(String value) {
  if (value.length <= 8) return '****';
  return '${value.substring(0, 3)}…${value.substring(value.length - 2)}';
}
