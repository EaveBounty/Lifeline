/// Web：浏览器自行处理代理，此处为空实现。
library;

import 'package:dio/dio.dart';

String? explicitProxy;

void configureProxy(Dio dio) {}

String? detectEnvProxy() => null;
