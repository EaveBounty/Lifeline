/// 轻量 Result 类型，用于不抛异常地传递失败。
///
/// 领域层/服务层对外返回 [Result]，UI 层据 [isOk] 分支。
/// 失败统一携带人类可读 [message] 与可选 [error] 原始异常。
library;

sealed class Result<T> {
  const Result();

  bool get isOk => this is Ok<T>;
  bool get isErr => this is Err<T>;

  /// 成功值；失败时为 null。
  T? get valueOrNull => this is Ok<T> ? (this as Ok<T>).value : null;

  /// 失败信息；成功时为 null。
  String? get errorMessage => this is Err<T> ? (this as Err<T>).message : null;

  R when<R>({
    required R Function(T value) ok,
    required R Function(String message, Object? error) err,
  }) {
    final self = this;
    if (self is Ok<T>) return ok(self.value);
    if (self is Err<T>) return err(self.message, self.error);
    throw StateError('unreachable');
  }
}

class Ok<T> extends Result<T> {
  final T value;
  const Ok(this.value);
}

class Err<T> extends Result<T> {
  final String message;
  final Object? error;
  const Err(this.message, [this.error]);
}
