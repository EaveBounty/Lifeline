/// PDF 页数统计（用于「严格 N 页」的确定性裁剪闭环）。
///
/// 直接扫描 `package:pdf` 生成的字节流中的页面对象词典。
/// 页面词典写作 `/Type /Page`，页面树写作 `/Type /Pages`，故需排除后者。
library;

import 'dart:convert';

final RegExp _pageObj = RegExp(r'/Type\s*/Page(?![s])');

/// 统计 PDF 字节流中的页数；解析失败返回 0（调用方据此放弃闭环）。
int countPdfPages(List<int> bytes) {
  final text = latin1.decode(bytes, allowInvalid: true);
  final n = _pageObj.allMatches(text).length;
  return n;
}
