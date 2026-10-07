/// OpenAI 兼容的底层大模型客户端（文本 + 视觉）。
///
/// 仅负责一次 HTTP 往返，不做提示词/业务编排；
/// 业务层（AiService / 导出服务）基于本类构建，保持解耦。
library;

import 'dart:convert';

import 'package:dio/dio.dart';

import '../../core/platform/io_platform.dart';
import '../../core/result.dart';

/// 多模态内容片段 → OpenAI chat 格式。
class LlmContent {
  final String type; // text | image
  final String value; // 文本 或 图片绝对路径
  const LlmContent.text(this.value) : type = 'text';
  const LlmContent.image(this.value) : type = 'image';

  /// 转为 OpenAI content part。
  Future<Map<String, dynamic>> toPart() async {
    if (type == 'text') return {'type': 'text', 'text': value};
    final bytes = await File(value).readAsBytes();
    final ext = value.split('.').last.toLowerCase();
    final mime = switch (ext) {
      'png' => 'image/png',
      'webp' => 'image/webp',
      'gif' => 'image/gif',
      'bmp' => 'image/bmp',
      'heic' => 'image/heic',
      _ => 'image/jpeg',
    };
    return {
      'type': 'image_url',
      'image_url': {'url': 'data:$mime;base64,${base64Encode(bytes)}'},
    };
  }
}

/// 一条消息。
class LlmMessage {
  final String role; // system | user | assistant
  final List<LlmContent> contents;
  const LlmMessage(this.role, this.contents);

  factory LlmMessage.text(String role, String text) =>
      LlmMessage(role, [LlmContent.text(text)]);

  Future<Map<String, dynamic>> toJson() async => {
        'role': role,
        'content': [for (final c in contents) await c.toPart()],
      };
}

class LlmClient {
  LlmClient({Dio? dio})
      : _dio = dio ??
            Dio(BaseOptions(
              connectTimeout: const Duration(seconds: 30),
              receiveTimeout: const Duration(seconds: 180),
            ));

  final Dio _dio;

  /// 一次 chat completion，返回助手文本。
  Future<Result<String>> chatCompletion({
    required String baseUrl,
    required String apiKey,
    required String model,
    required List<LlmMessage> messages,
    bool jsonMode = false,
    Map<String, String> extraHeaders = const {},
  }) async {
    if (baseUrl.trim().isEmpty || model.trim().isEmpty) {
      return const Err<String>('未配置 base_url 或 model');
    }
    try {
      final url = '${baseUrl.trimRight().replaceAll(RegExp(r'/+$'), '')}/chat/completions';
      final body = <String, dynamic>{
        'model': model,
        'messages': [for (final m in messages) await m.toJson()],
        if (jsonMode) 'response_format': {'type': 'json_object'},
      };
      final resp = await _dio.post<Map<String, dynamic>>(
        url,
        data: jsonEncode(body),
        options: Options(
          headers: {
            'Authorization': 'Bearer $apiKey',
            'Content-Type': 'application/json',
            ...extraHeaders,
          },
        ),
      );
      final data = resp.data;
      final choices = data?['choices'] as List?;
      if (choices == null || choices.isEmpty) {
        return Err<String>('模型返回为空: ${data?['error'] ?? resp.statusCode}');
      }
      final msg = (choices.first as Map)['message'] as Map?;
      final content = msg?['content'];
      if (content is String) return Ok(content);
      if (content is List) {
        final sb = StringBuffer();
        for (final part in content) {
          if (part is Map && part['text'] != null) sb.write(part['text']);
        }
        return Ok(sb.toString());
      }
      return const Err<String>('无法解析模型输出');
    } on DioException catch (e) {
      if (e.response?.statusCode != null) {
        return Err<String>(
          '请求失败(HTTP ${e.response!.statusCode})：${_briefBody(e.response?.data)}',
          e,
        );
      }
      return Err<String>(describeDioError(e), e);
    } catch (e) {
      return Err<String>('请求异常: $e', e);
    }
  }
}

/// 把底层网络异常转成可诊断的中文说明。
String describeDioError(DioException e) {
  final extra = (e.message ?? '').trim();
  final suffix = extra.isEmpty ? '' : '（$extra）';
  return switch (e.type) {
    DioExceptionType.connectionTimeout =>
      '连接超时：无法到达服务器，请检查网络或代理$suffix',
    DioExceptionType.sendTimeout => '发送超时$suffix',
    DioExceptionType.receiveTimeout => '响应超时：服务器无响应$suffix',
    DioExceptionType.badCertificate => 'TLS 证书校验失败$suffix',
    DioExceptionType.connectionError =>
      '无法连接：域名解析失败，或被网络/防火墙/代理拦截。请检查网络、代理与 base_url$suffix',
    DioExceptionType.badResponse => '服务器返回异常$suffix',
    DioExceptionType.cancel => '请求已取消$suffix',
    DioExceptionType.unknown =>
      '未知网络错误：可能是域名解析失败、CORS（网页端）或证书问题。请检查网络与 base_url$suffix',
    _ => '网络错误$suffix',
  };
}

String _briefBody(dynamic data) {
  if (data == null) return '';
  var s = data.toString();
  if (s.length > 300) s = s.substring(0, 300);
  return s;
}

/// 从可能带 ```json 代码块的文本中提取 JSON 字符串。
String extractJsonBlock(String text) {
  final fence = RegExp(r'```(?:json)?\s*([\s\S]*?)```');
  final m = fence.firstMatch(text);
  if (m != null) return m.group(1)!.trim();
  final start = text.indexOf('{');
  final end = text.lastIndexOf('}');
  if (start >= 0 && end > start) return text.substring(start, end + 1);
  return text.trim();
}
