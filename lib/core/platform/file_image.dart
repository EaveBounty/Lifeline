/// 文件图片组件入口：原生用 Image.file，Web 用内存字节 Image.memory。
library;

export 'file_image_io.dart'
    if (dart.library.js_interop) 'file_image_web.dart';
