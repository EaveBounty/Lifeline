/// Web 端无法调用本机 TeX 引擎：始终返回 null（只保留 .tex 源码）。
library;

Future<List<int>?> compileLatex(String tex) async => null;
