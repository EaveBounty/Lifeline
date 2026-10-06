#!/usr/bin/env bash
# 本地预览 Web 构建产物（构建后运行）。
set -euo pipefail
cd "$(dirname "$0")/../build/web"
exec python3 -m http.server 8080
