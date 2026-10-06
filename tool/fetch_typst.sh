#!/usr/bin/env bash
# 下载 Typst 独立二进制到构建资产目录（供桌面端精美 PDF 渲染）。
# 用法: bash tool/fetch_typst.sh [目标目录]   (默认 build_assets/typst/<platform>/)
# 版本可用 TYPST_VERSION 覆盖，默认 0.15.1。
# 找不到/下载失败不应阻塞构建（渲染器会回退到纯 Dart PDF）。
set -euo pipefail

VERSION="${TYPST_VERSION:-0.15.1}"
DEST="${1:-build_assets/typst}"

OS="$(uname -s)"
ARCH="$(uname -m)"

case "$OS" in
  Linux)   PLAT="linux";   EXT="tar.xz"; TARGET="x86_64-unknown-linux-musl" ;;
  Darwin)  PLAT="macos";   EXT="tar.xz"; TARGET="x86_64-apple-darwin" ;;
  MINGW*|MSYS*|CYGWIN*) PLAT="windows"; EXT="zip"; TARGET="x86_64-pc-windows-msvc" ;;
  *) echo "不支持的平台: $OS（跳过 Typst）"; exit 0 ;;
esac

case "$ARCH" in
  aarch64|arm64) TARGET="${TARGET/x86_64/aarch64}" ;;
esac

URL="https://github.com/typst/typst/releases/download/v${VERSION}/typst-${TARGET}.${EXT}"

echo "下载 Typst v${VERSION}: $URL"
TMP="$(mktemp -d)"
trap 'rm -rf "$TMP"' EXIT

if ! curl -fL --retry 3 --connect-timeout 20 -o "$TMP/pkg.$EXT" "$URL"; then
  echo "Typst 下载失败（跳过，运行时将回退 DartPdf）"; exit 0
fi

if [ "$EXT" = "zip" ]; then
  unzip -o "$TMP/pkg.zip" -d "$TMP/x" >/dev/null
else
  mkdir -p "$TMP/x"
  tar -xf "$TMP/pkg.tar.xz" -C "$TMP/x"
fi

BIN="$(find "$TMP/x" \( -name typst -o -name typst.exe \) -type f | head -n1 || true)"
if [ -z "$BIN" ]; then
  echo "未在压缩包中找到 typst 可执行文件"; exit 0
fi

mkdir -p "$DEST/$PLAT"
cp "$BIN" "$DEST/$PLAT/"
chmod +x "$DEST/$PLAT/"* 2>/dev/null || true
echo "已放置: $DEST/$PLAT/$(basename "$BIN")"
