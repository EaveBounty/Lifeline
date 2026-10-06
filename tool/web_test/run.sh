#!/usr/bin/env bash
# 一键：构建 web（若无产物）→ 起本地服务 → 跑 Playwright 端到端测试 + 截图 → 关服务。
#
# 仅针对本地自建 web 应用，不访问外部站点。
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/../.." && pwd)"
cd "$ROOT"

PORT="${WEB_TEST_PORT:-8099}"
BASE_URL="http://127.0.0.1:${PORT}/"
SCREENSHOT_DIR="${SCREENSHOT_DIR:-$ROOT/docs/assets}"
export BASE_URL SCREENSHOT_DIR

# 1) 构建产物（缺失或源码更新则构建）
NEED_BUILD=0
if [[ ! -f "$ROOT/build/web/index.html" ]]; then
  NEED_BUILD=1
elif [[ -n "$(find "$ROOT/lib" "$ROOT/pubspec.yaml" -newer "$ROOT/build/web/main.dart.js" -print -quit 2>/dev/null)" ]]; then
  NEED_BUILD=1
fi
[[ "${WEB_TEST_REBUILD:-0}" == "1" ]] && NEED_BUILD=1
if [[ "$NEED_BUILD" == "1" ]]; then
  echo "[run.sh] 构建产物缺失或源码较新，执行 flutter build web ..."
  flutter build web --release --no-web-resources-cdn
fi

# 2) 解析 Playwright 模块位置（不新增依赖，复用本机已有的 node_modules）
if ! node -e "require('playwright')" >/dev/null 2>&1; then
  PW_CANDIDATES=(
    "${PW_NODE_MODULES:-}"
    "$HOME/program/github/platform/frontend/node_modules"
    "$HOME/services/uptime-kuma/node_modules"
    "$ROOT/node_modules"
  )
  for d in "${PW_CANDIDATES[@]}"; do
    if [[ -n "$d" && -f "$d/playwright/package.json" ]]; then
      export NODE_PATH="$d${NODE_PATH:+:$NODE_PATH}"
      echo "[run.sh] 使用 Playwright: $d"
      break
    fi
  done
  # 退回 npx 缓存
  if ! node -e "require('playwright')" >/dev/null 2>&1; then
    CACHE_PW="$(find "$HOME/.npm/_npx" -maxdepth 4 -type f -path '*/node_modules/playwright/package.json' 2>/dev/null | head -1 || true)"
    if [[ -n "$CACHE_PW" ]]; then
      export NODE_PATH="$(dirname "$(dirname "$CACHE_PW")")${NODE_PATH:+:$NODE_PATH}"
      echo "[run.sh] 使用 npx 缓存的 Playwright: $NODE_PATH"
    fi
  fi
fi

if ! node -e "require('playwright')" >/dev/null 2>&1; then
  echo "[run.sh] 无法解析 playwright；请安装或设置 PW_NODE_MODULES 指向含 playwright 的 node_modules。" >&2
  exit 2
fi

# 3) 起本地静态服务
echo "[run.sh] 启动本地服务 http://127.0.0.1:${PORT}/ ..."
python3 -m http.server "$PORT" --directory "$ROOT/build/web" >/tmp/lifeline-web-test-server.log 2>&1 &
SERVER_PID=$!
trap 'kill "$SERVER_PID" >/dev/null 2>&1 || true' EXIT

for _ in $(seq 1 50); do
  if curl -sf -o /dev/null "$BASE_URL"; then break; fi
  sleep 0.2
done
if ! curl -sf -o /dev/null "$BASE_URL"; then
  echo "[run.sh] 本地服务未就绪。" >&2
  exit 2
fi

# 4) 跑测试 + 截图
set +e
node "$ROOT/tool/web_test/web_e2e.js"
CODE=$?
set -e

echo "[run.sh] 退出码 = $CODE"
exit "$CODE"
