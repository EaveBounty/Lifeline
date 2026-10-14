/// LaTeX 编译入口：桌面端尝试本机 xelatex/latexmk，其它平台返回 null。
library;

export 'latex_compiler_io.dart'
    if (dart.library.js_interop) 'latex_compiler_web.dart';
