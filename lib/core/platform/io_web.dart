/// Web 内存文件系统：实现项目实际用到的 dart:io 子集。
///
/// 目的：让依赖 `dart:io` 的仓库/服务在浏览器中可编译并可运行。
/// 语义为「进程内内存卷」——刷新页面即清空（除非镜像到 localStorage）。
/// 仅覆盖本项目调用到的成员；未覆盖者视为未实现。
library;

import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';

// --- 全局内存卷 ---

final Map<String, List<int>> _files = <String, List<int>>{};
final Map<String, DateTime> _mtime = <String, DateTime>{};
final Set<String> _dirs = <String>{'/'};

/// 归一化为绝对 POSIX 风格路径。
String _norm(String path) {
  var s = path.replaceAll(r'\', '/').trim();
  if (s.isEmpty) return '/';
  if (!s.startsWith('/')) s = '/$s';
  final out = <String>[];
  for (final seg in s.split('/')) {
    if (seg.isEmpty || seg == '.') continue;
    if (seg == '..') {
      if (out.isNotEmpty) out.removeLast();
    } else {
      out.add(seg);
    }
  }
  return '/${out.join('/')}';
}

String _parentOf(String path) {
  final n = _norm(path);
  final i = n.lastIndexOf('/');
  if (i <= 0) return '/';
  return n.substring(0, i);
}

bool _under(String parent, String child) {
  if (parent == '/') return child != '/';
  return child.startsWith('$parent/');
}

void _ensureDirs(String path) {
  final n = _norm(path);
  var cur = '';
  for (final part in n.split('/').where((e) => e.isNotEmpty)) {
    cur = '$cur/$part';
    _dirs.add(cur);
  }
}

// --- 异常 ---

class IOException implements Exception {
  IOException([this.message = '']);

  final String message;

  @override
  String toString() => 'IOException: $message';
}

class FileSystemException extends IOException {
  FileSystemException([super.message = '', this.path = '', this.osError]);

  final String path;
  final Object? osError;

  @override
  String toString() =>
      "FileSystemException: $message, path = '$path'"
      "${osError == null ? '' : ' ($osError)'}";
}

// --- 类型 ---

class FileSystemEntityType {
  const FileSystemEntityType._(this.name);

  final String name;

  static const FileSystemEntityType file = FileSystemEntityType._('file');
  static const FileSystemEntityType directory =
      FileSystemEntityType._('directory');
  static const FileSystemEntityType link = FileSystemEntityType._('link');
  static const FileSystemEntityType notFound =
      FileSystemEntityType._('notFound');

  @override
  String toString() => name;
}

class FileStat {
  const FileStat(this.modified, this.size, this.mode);

  final DateTime modified;
  final int size;
  final int mode;

  static const int _fileType = 0x8000;

  static FileStat _file(DateTime m, int size) => FileStat(m, size, _fileType);
}

// --- 实体 ---

class FileSystemEntity {
  FileSystemEntity(String path) : path = _norm(path);

  final String path;

  static Future<FileSystemEntityType> type(
    String path, {
    bool followLinks = true,
  }) async =>
      typeSync(path, followLinks: followLinks);

  static FileSystemEntityType typeSync(
    String path, {
    bool followLinks = true,
  }) {
    final n = _norm(path);
    if (_files.containsKey(n)) return FileSystemEntityType.file;
    if (_dirs.contains(n)) return FileSystemEntityType.directory;
    return FileSystemEntityType.notFound;
  }

  static Future<bool> isDirectory(String path) async =>
      typeSync(path) == FileSystemEntityType.directory;

  static bool isDirectorySync(String path) =>
      typeSync(path) == FileSystemEntityType.directory;

  static Future<bool> isFile(String path) async =>
      typeSync(path) == FileSystemEntityType.file;

  static bool isFileSync(String path) =>
      typeSync(path) == FileSystemEntityType.file;
}

class File extends FileSystemEntity {
  File(super.path);

  File get absolute => File(path);

  Directory get parent => Directory(_parentOf(path));

  Future<bool> exists() async => _files.containsKey(path);

  bool existsSync() => _files.containsKey(path);

  Future<Uint8List> readAsBytes() async {
    final bytes = _files[path];
    if (bytes == null) {
      throw FileSystemException('Cannot open file', path);
    }
    return Uint8List.fromList(bytes);
  }

  Future<String> readAsString({Encoding encoding = utf8}) async =>
      encoding.decode(await readAsBytes());

  Future<void> writeAsBytes(
    List<int> bytes, {
    bool flush = false,
    dynamic mode,
  }) async {
    _ensureDirs(_parentOf(path));
    _files[path] = List<int>.from(bytes);
    _mtime[path] = DateTime.now();
  }

  Future<void> writeAsString(
    String contents, {
    Encoding encoding = utf8,
    bool flush = false,
    dynamic mode,
  }) =>
      writeAsBytes(encoding.encode(contents), flush: flush);

  Future<File> rename(String newPath) async {
    if (!_files.containsKey(path)) {
      throw FileSystemException('Cannot rename', path);
    }
    final dst = _norm(newPath);
    _ensureDirs(_parentOf(dst));
    _files[dst] = _files.remove(path)!;
    final m = _mtime.remove(path);
    if (m != null) _mtime[dst] = m;
    return File(dst);
  }

  Future<File> copy(String newPath) async {
    final bytes = _files[path];
    if (bytes == null) {
      throw FileSystemException('Cannot copy', path);
    }
    final dst = _norm(newPath);
    _ensureDirs(_parentOf(dst));
    _files[dst] = List<int>.from(bytes);
    _mtime[dst] = DateTime.now();
    return File(dst);
  }

  Future<FileSystemEntity> delete({bool recursive = false}) async {
    _files.remove(path);
    _mtime.remove(path);
    return File(path);
  }

  Future<FileStat> stat() async => statSync();

  FileStat statSync() {
    final bytes = _files[path];
    if (bytes == null) {
      throw FileSystemException('Cannot stat', path);
    }
    return FileStat._file(
      _mtime[path] ?? DateTime.fromMillisecondsSinceEpoch(0),
      bytes.length,
    );
  }

  int lengthSync() {
    final bytes = _files[path];
    if (bytes == null) {
      throw FileSystemException('Cannot get length', path);
    }
    return bytes.length;
  }

  Future<int> length() async => lengthSync();

  DateTime lastModifiedSync() =>
      _mtime[path] ?? DateTime.fromMillisecondsSinceEpoch(0);
}

class Directory extends FileSystemEntity {
  Directory(super.path);

  Directory get absolute => Directory(path);

  Directory get parent => Directory(_parentOf(path));

  static Directory get systemTemp => Directory('/tmp');

  static Directory get current => Directory('/');

  Future<Directory> createTemp(String prefix) async {
    final dir = Directory('/tmp/$prefix${DateTime.now().microsecondsSinceEpoch}');
    _ensureDirs(dir.path);
    return dir;
  }

  Future<bool> exists() async => _dirs.contains(path);

  bool existsSync() => _dirs.contains(path);

  Future<Directory> create({bool recursive = false}) async {
    if (recursive) {
      _ensureDirs(path);
    } else {
      _dirs.add(path);
    }
    return Directory(path);
  }

  Directory createSync({bool recursive = false}) {
    if (recursive) {
      _ensureDirs(path);
    } else {
      _dirs.add(path);
    }
    return Directory(path);
  }

  List<FileSystemEntity> _directChildren() {
    final out = <FileSystemEntity>[];
    for (final d in _dirs) {
      if (d != '/' && _parentOf(d) == path) out.add(Directory(d));
    }
    for (final f in _files.keys) {
      if (_parentOf(f) == path) out.add(File(f));
    }
    return out;
  }

  List<FileSystemEntity> listSync({
    bool recursive = false,
    bool followLinks = true,
  }) {
    if (!_dirs.contains(path)) {
      throw FileSystemException('Directory does not exist', path);
    }
    final out = <FileSystemEntity>[..._directChildren()];
    if (recursive) {
      for (final d in _dirs.toList()) {
        if (d == path || !_under(path, d)) continue;
        out.add(Directory(d));
        for (final f in _files.keys) {
          if (_parentOf(f) == d) out.add(File(f));
        }
      }
    }
    return out;
  }

  Stream<FileSystemEntity> list({
    bool recursive = false,
    bool followLinks = true,
  }) =>
      Stream<FileSystemEntity>.fromIterable(
        listSync(recursive: recursive, followLinks: followLinks),
      );

  Future<Directory> delete({bool recursive = false}) async {
    if (recursive) {
      _dirs.removeWhere((d) => d == path || _under(path, d));
      _files.removeWhere((f, _) => _under(path, f));
      _mtime.removeWhere((f, _) => _under(path, f));
    } else {
      _dirs.remove(path);
      _files.removeWhere((f, _) => _parentOf(f) == path);
      _mtime.removeWhere((f, _) => _parentOf(f) == path);
    }
    return Directory(path);
  }

  Directory deleteSync({bool recursive = false}) {
    if (recursive) {
      _dirs.removeWhere((d) => d == path || _under(path, d));
      _files.removeWhere((f, _) => _under(path, f));
      _mtime.removeWhere((f, _) => _under(path, f));
    } else {
      _dirs.remove(path);
      _files.removeWhere((f, _) => _parentOf(f) == path);
      _mtime.removeWhere((f, _) => _parentOf(f) == path);
    }
    return Directory(path);
  }
}

// --- 平台 ---

class Platform {
  Platform._();

  // Web 上所有桌面/移动平台标识均为 false。
  static bool get isWindows => false;
  static bool get isMacOS => false;
  static bool get isLinux => false;
  static bool get isAndroid => false;
  static bool get isIOS => false;
  static bool get isFuchsia => false;

  static String get pathSeparator => '/';
  static String get operatingSystem => 'web';
  static int get numberOfProcessors => 1;
  static String get resolvedExecutable => '';
  static Map<String, String> get environment => const <String, String>{};
  static String get localHostname => 'localhost';
}

// --- 进程 ---

class ProcessResult {
  ProcessResult(this.pid, this.exitCode, this.stdout, this.stderr);

  final int pid;
  final int exitCode;
  final dynamic stdout;
  final dynamic stderr;
}

class Process {
  Process._();

  static Future<ProcessResult> run(
    String executable,
    List<String> arguments, {
    String? workingDirectory,
    Map<String, String>? environment,
    bool includeParentEnvironment = true,
    bool runInShell = false,
    Encoding? stdoutEncoding = systemEncoding,
    Encoding? stderrEncoding = systemEncoding,
  }) async {
    throw UnsupportedError('Process is not supported on the web');
  }

  static ProcessResult runSync(
    String executable,
    List<String> arguments, {
    String? workingDirectory,
    Map<String, String>? environment,
    bool includeParentEnvironment = true,
    bool runInShell = false,
    Encoding? stdoutEncoding = systemEncoding,
    Encoding? stderrEncoding = systemEncoding,
  }) {
    throw UnsupportedError('Process is not supported on the web');
  }
}

/// 与 dart:io 的 `systemEncoding` 对齐（web 无原生编码，取 utf8）。
const Encoding systemEncoding = utf8;
