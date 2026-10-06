#!/usr/bin/env python3
"""Lifeline · 履痕 应用图标生成器。

用 Python 绘制 SVG（矢量源），再用 ImageMagick 栅格化为各平台所需尺寸。
设计：深蓝圆角徽章 + 白色「履历卡片」（头像/姓名/条目）+ 上升的成果条形与连线轨迹，
寓意「人生履痕 / 履历」，强调色由蓝到暖金渐变。

用法: python3 tool/gen_icon.py            # 生成 SVG + 各平台 PNG/ICO
需要: ImageMagick (`magick`) 用于栅格化。
"""
from __future__ import annotations

import os
import subprocess
import sys

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
ICON_DIR = os.path.join(ROOT, "assets", "icon")

# 品牌色（扁平化，避免依赖 SVG 渐变渲染器）
BG = "#2E5A88"
INK = "#1C3C60"
BLUE = "#2E5A88"
BLUE_LIGHT = "#7FB2E5"
BAR_RAMP = ["#7FB2E5", "#A9C7E8", "#E9C87E", "#FFC065"]
GOLD = "#FFC065"
GOLD_DEEP = "#F0A94B"
MUTED = "#94A3B8"


def _svg(maskable: bool) -> str:
    """生成图标 SVG。maskable=True 时满幅背景、内容缩至安全区。"""
    radius = 0 if maskable else 224
    scale = 0.72 if maskable else 1.0
    cx, cy = 512, 512
    transform = f"translate({cx} {cy}) scale({scale}) translate({-cx} {-cy})"
    bars = "".join(
        f'\n    <rect x="{x}" y="{y}" width="70" height="{h}" rx="18" fill="{c}"/>'
        for (x, y, h, c) in zip(
            (332, 428, 524, 620), (636, 576, 516, 456), (116, 176, 236, 296), BAR_RAMP
        )
    )
    return f"""<svg xmlns="http://www.w3.org/2000/svg" width="1024" height="1024" viewBox="0 0 1024 1024">
  <rect x="0" y="0" width="1024" height="1024" rx="{radius}" fill="{BG}"/>
  <circle cx="286" cy="238" r="360" fill="#ffffff" opacity="0.06"/>
  <g transform="{transform}">
    <rect x="300" y="272" width="456" height="552" rx="54" fill="#14304F" opacity="0.35"/>
    <rect x="286" y="246" width="452" height="560" rx="52" fill="#ffffff"/>
    <circle cx="372" cy="342" r="44" fill="{BLUE}"/>
    <circle cx="372" cy="329" r="16" fill="#ffffff"/>
    <path d="M347 373 q25 -28 50 0 z" fill="#ffffff"/>
    <rect x="440" y="314" width="224" height="28" rx="14" fill="{INK}"/>
    <rect x="440" y="356" width="150" height="20" rx="10" fill="{BLUE_LIGHT}"/>
    <rect x="332" y="432" width="360" height="18" rx="9" fill="{MUTED}"/>
    <rect x="332" y="472" width="292" height="18" rx="9" fill="{MUTED}"/>
    <rect x="332" y="512" width="320" height="18" rx="9" fill="{MUTED}" opacity="0.7"/>{bars}
    <path d="M367 618 L463 558 L559 498 L655 438"
          stroke="{GOLD}" stroke-width="15" stroke-linecap="round"
          stroke-linejoin="round" fill="none"/>
    <circle cx="367" cy="618" r="15" fill="#ffffff" stroke="{GOLD}" stroke-width="8"/>
    <circle cx="655" cy="438" r="19" fill="{GOLD_DEEP}"/>
    <circle cx="655" cy="438" r="9" fill="#ffffff"/>
  </g>
</svg>"""


def write_svg(path: str, content: str) -> None:
    with open(path, "w", encoding="utf-8") as f:
        f.write(content)
    print(f"  svg  {os.path.relpath(path, ROOT)}")


def render(svg: str, out: str, size: int) -> None:
    os.makedirs(os.path.dirname(out), exist_ok=True)
    subprocess.run(
        ["magick", "-background", "none", svg, "-resize", f"{size}x{size}",
         "-depth", "8", f"PNG32:{out}"],
        check=True,
    )
    print(f"  png  {os.path.relpath(out, ROOT)} ({size})")


def render_ico(png512: str, out: str) -> None:
    os.makedirs(os.path.dirname(out), exist_ok=True)
    subprocess.run(
        ["magick", png512, "-define", "icon:auto-resize=256,128,64,48,32,16", out],
        check=True,
    )
    print(f"  ico  {os.path.relpath(out, ROOT)}")


def main() -> int:
    if subprocess.run(["which", "magick"], capture_output=True).returncode != 0:
        print("需要 ImageMagick(magick) 才能栅格化。", file=sys.stderr)
        return 1

    os.makedirs(ICON_DIR, exist_ok=True)
    rounded = _svg(maskable=False)
    mask = _svg(maskable=True)

    svg_rounded = os.path.join(ICON_DIR, "app_icon.svg")
    svg_mask = os.path.join(ICON_DIR, "app_icon_maskable.svg")
    write_svg(svg_rounded, rounded)
    write_svg(svg_mask, mask)

    # 主母版 1024
    master = os.path.join(ICON_DIR, "app_icon_1024.png")
    render(svg_rounded, master, 1024)
    mask_master = os.path.join(ICON_DIR, "app_icon_maskable_1024.png")
    render(svg_mask, mask_master, 1024)

    # Android mipmaps
    android = os.path.join(ROOT, "android", "app", "src", "main", "res")
    for dpi, size in [("mdpi", 48), ("hdpi", 72), ("xhdpi", 96),
                      ("xxhdpi", 144), ("xxxhdpi", 192)]:
        render(svg_rounded, os.path.join(android, f"mipmap-{dpi}", "ic_launcher.png"), size)

    # Web
    web_icons = os.path.join(ROOT, "web", "icons")
    render(svg_rounded, os.path.join(web_icons, "Icon-192.png"), 192)
    render(svg_rounded, os.path.join(web_icons, "Icon-512.png"), 512)
    render(svg_mask, os.path.join(web_icons, "Icon-maskable-192.png"), 192)
    render(svg_mask, os.path.join(web_icons, "Icon-maskable-512.png"), 512)
    render(svg_rounded, os.path.join(ROOT, "web", "favicon.png"), 64)

    # Windows ICO
    render_ico(
        os.path.join(web_icons, "Icon-512.png"),
        os.path.join(ROOT, "windows", "runner", "resources", "app_icon.ico"),
    )

    # Linux / README 展示用
    render(svg_rounded, os.path.join(ICON_DIR, "app_icon_256.png"), 256)
    render(svg_rounded, os.path.join(ROOT, "docs", "assets", "icon.png"), 512)

    print("完成。")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
