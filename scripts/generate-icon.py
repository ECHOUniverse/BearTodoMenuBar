#!/usr/bin/env python3
"""Generate pixel-art macOS app icon for BearTodoMenuBar."""

import os
import subprocess
import sys
from pathlib import Path

from PIL import Image, ImageDraw

# ---------------------------------------------------------------------------
# Config
# ---------------------------------------------------------------------------
CANVAS = 1024
GRID = 32                     # 32×32 logical pixels
PIXEL = CANVAS // GRID        # 32 physical px per logical pixel
OUTPUT_DIR = Path(__file__).resolve().parent.parent / "resources"
ICONSET_DIR = OUTPUT_DIR / "AppIcon.iconset"

def ensure_dirs():
    OUTPUT_DIR.mkdir(parents=True, exist_ok=True)
    ICONSET_DIR.mkdir(parents=True, exist_ok=True)

# ---------------------------------------------------------------------------
# Palette (RGB)
# ---------------------------------------------------------------------------
BG_COLOR       = (50, 55, 65)       # 深蓝灰 macOS 风格背景
NOTE_COLOR     = (255, 248, 220)    # 米黄便笺
NOTE_SHADOW    = (230, 220, 190)    # 便笺暗部/折角
BEAR_RED       = (220, 60, 60)      # Bear 红
BEAR_WHITE     = (255, 255, 255)    # 熊肚子/脸
BEAR_DARK      = (180, 40, 40)      # 熊阴影
EYE_COLOR      = (30, 30, 30)       # 眼睛

# ---------------------------------------------------------------------------
# Pixel helpers (pixel-art coordinates → physical rect)
# ---------------------------------------------------------------------------
def rect(x, y, w=1, h=1):
    """Return physical bounding box for a logical pixel block."""
    return [
        x * PIXEL,
        y * PIXEL,
        (x + w) * PIXEL,
        (y + h) * PIXEL,
    ]

def fill(draw, x, y, color, w=1, h=1):
    draw.rectangle(rect(x, y, w, h), fill=color)

# ---------------------------------------------------------------------------
# Drawing layers
# ---------------------------------------------------------------------------
def draw_background(draw):
    """macOS 标准圆角矩形背景（用像素近似圆角）."""
    for y in range(GRID):
        for x in range(GRID):
            # 圆角裁切：四个角各去掉 2×2 的逻辑像素
            if (x < 2 and y < 2) or (x >= GRID - 2 and y < 2) or \
               (x < 2 and y >= GRID - 2) or (x >= GRID - 2 and y >= GRID - 2):
                continue
            fill(draw, x, y, BG_COLOR)

def draw_note(draw):
    """米黄色便笺，带右下角折角效果."""
    nx, ny = 4, 6          # 便笺起始逻辑坐标
    nw, nh = 24, 22        # 便笺宽高

    # 主体
    for y in range(ny, ny + nh):
        for x in range(nx, nx + nw):
            fill(draw, x, y, NOTE_COLOR)

    # 轻微阴影/折角（右下角 4×4 区域）
    for y in range(ny + nh - 4, ny + nh):
        for x in range(nx + nw - 4, nx + nw):
            fill(draw, x, y, NOTE_SHADOW)

    # 顶部线条（模拟便笺头）
    for x in range(nx, nx + nw):
        fill(draw, x, ny, (220, 210, 180))

def draw_bear(draw):
    """简化的像素 Bear：圆头、白腹、小耳朵，居中偏上."""
    # 熊中心基准
    cx, cy = 16, 14

    # 耳朵 (左右各 2×2)
    fill(draw, cx - 5, cy - 6, BEAR_RED, 2, 2)
    fill(draw, cx + 3, cy - 6, BEAR_RED, 2, 2)

    # 头部 (8×6)
    fill(draw, cx - 4, cy - 4, BEAR_RED, 8, 6)

    # 脸部白色区域 (6×4)
    fill(draw, cx - 3, cy - 2, BEAR_WHITE, 6, 4)

    # 眼睛 (2×1)
    fill(draw, cx - 2, cy - 1, EYE_COLOR, 1, 1)
    fill(draw, cx + 1, cy - 1, EYE_COLOR, 1, 1)

    # 身体 (10×8)
    fill(draw, cx - 5, cy + 2, BEAR_RED, 10, 8)

    # 肚子白色 (6×5)
    fill(draw, cx - 3, cy + 4, BEAR_WHITE, 6, 5)

    # 手臂 (各 2×3)
    fill(draw, cx - 7, cy + 3, BEAR_RED, 2, 3)
    fill(draw, cx + 5, cy + 3, BEAR_RED, 2, 3)

    # 脚 (各 2×2)
    fill(draw, cx - 4, cy + 9, BEAR_DARK, 2, 2)
    fill(draw, cx + 2, cy + 9, BEAR_DARK, 2, 2)

# ---------------------------------------------------------------------------
# Main render
# ---------------------------------------------------------------------------
def render_master() -> Image.Image:
    img = Image.new("RGBA", (CANVAS, CANVAS), (0, 0, 0, 0))
    draw = ImageDraw.Draw(img)
    draw_background(draw)
    draw_note(draw)
    draw_bear(draw)
    return img

# ---------------------------------------------------------------------------
# macOS iconset generation
# ---------------------------------------------------------------------------
MACOS_SIZES = [
    (16, 1), (32, 1), (32, 2), (64, 1),
    (128, 1), (256, 1), (128, 2), (256, 2),
    (512, 1), (512, 2), (1024, 2),
]

def generate_iconset(master: Image.Image):
    for size, scale in MACOS_SIZES:
        px = size * scale
        suffix = f"{size}x{size}"
        if scale > 1:
            suffix += f"@{scale}x"
        resized = master.resize((px, px), Image.Resampling.NEAREST)
        path = ICONSET_DIR / f"icon_{suffix}.png"
        resized.save(path)
        print(f"  → {path.name}")

def pack_icns() -> Path:
    icns_path = OUTPUT_DIR / "AppIcon.icns"
    try:
        subprocess.run(
            ["iconutil", "-c", "icns", str(ICONSET_DIR), "-o", str(icns_path)],
            check=True,
        )
        print(f"  → {icns_path.name}")
    except FileNotFoundError:
        print("⚠️  iconutil not found (requires macOS). Skipping .icns packing.")
        sys.exit(1)
    return icns_path

# ---------------------------------------------------------------------------
# Entry
# ---------------------------------------------------------------------------
def main():
    print("🎨 Rendering 1024×1024 pixel-art master...")
    ensure_dirs()
    master = render_master()
    master.save(OUTPUT_DIR / "icon_1024x1024.png")
    print(f"  → icon_1024x1024.png")

    print("📐 Generating iconset sizes...")
    generate_iconset(master)

    print("📦 Packing into AppIcon.icns...")
    pack_icns()

    print(f"✅ Done. Output: {OUTPUT_DIR}")

if __name__ == "__main__":
    main()
