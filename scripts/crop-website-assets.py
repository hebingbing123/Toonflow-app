#!/usr/bin/env python3
"""从 website/assets/source/ 设计拼板裁剪宣传页素材（百分比坐标，适配高清源图）。"""
from __future__ import annotations

import os
from pathlib import Path

from PIL import Image

ROOT = Path(__file__).resolve().parents[1]
SRC = ROOT / "website/assets/source"
OUT = ROOT / "website/assets/screenshots"

BOARD = SRC / "ChatGPT Image 2026年5月23日 12_39_47.png"
VERT = SRC / "1582682143637361566.jpg"
# 回退
BOARD_FALLBACK = SRC / "design-board.png"
VERT_FALLBACK = SRC / "design-vertical.png"


def pick(*paths: Path) -> Path:
    for p in paths:
        if p.is_file():
            return p
    raise FileNotFoundError(f"Missing source: {paths}")


def box_from_pct(im: Image.Image, x0: float, y0: float, x1: float, y1: float) -> tuple[int, int, int, int]:
    w, h = im.size
    l, t = int(x0 * w), int(y0 * h)
    r, b = int(x1 * w), int(y1 * h)
    return (max(0, l), max(0, t), min(w, r), min(h, b))


def save_crop(im: Image.Image, pct: tuple[float, float, float, float], name: str, scale2: bool = True) -> None:
    crop = im.crop(box_from_pct(im, *pct)).convert("RGB")
    path = OUT / name
    crop.save(path, "PNG", optimize=True)
    if scale2:
        c2 = crop.resize((crop.width * 2, crop.height * 2), Image.Resampling.LANCZOS)
        c2.save(OUT / name.replace(".png", "@2x.png"), "PNG", optimize=True)
    print(f"  {name}: {crop.size}" + (" +@2x" if scale2 else ""))


def main() -> None:
    OUT.mkdir(parents=True, exist_ok=True)
    board_path = pick(BOARD, BOARD_FALLBACK)
    vert_path = pick(VERT, VERT_FALLBACK)
    board = Image.open(board_path)
    vert = Image.open(vert_path)
    print(f"Board: {board_path.name} {board.size}")
    print(f"Vert:  {vert_path.name} {vert.size}")

    # --- 竖版：顶部三栏能力 + 横幅 ---
    print("Vertical / features:")
    save_crop(vert, (0.01, 0.085, 0.99, 0.39), "features-trio.png")
    save_crop(vert, (0.02, 0.07, 0.33, 0.39), "feature-script.png")
    save_crop(vert, (0.34, 0.07, 0.66, 0.39), "feature-storyboard.png")
    save_crop(vert, (0.67, 0.07, 0.99, 0.39), "feature-collab.png")
    save_crop(vert, (0.70, 0.51, 0.99, 0.70), "feature-private.png")

    # --- 横版高清板：手机 / 桌面 / Web ---
    print("Board / platforms:")
    for i, tag in enumerate(
        ["01-projects", "02-script", "03-storyboard", "04-team", "05-summary"], start=1
    ):
        x0 = 0.008 + (i - 1) * 0.196
        save_crop(board, (x0, 0.055, x0 + 0.188, 0.335), f"mobile-{tag}.png", scale2=False)

    save_crop(board, (0.015, 0.055, 0.205, 0.335), "mobile-app.png", scale2=False)
    save_crop(board, (0.02, 0.355, 0.50, 0.625), "desktop-studio.png", scale2=False)
    save_crop(board, (0.50, 0.37, 0.98, 0.58), "web-app.png", scale2=False)
    save_crop(board, (0.52, 0.58, 0.98, 0.78), "web-hero.png", scale2=False)

    # 横版底部四宫格能力卡（高清，用于卡片配图）
    print("Board / feature cards:")
    for i, key in enumerate(["script", "storyboard", "collab", "private"]):
        x0 = 0.01 + i * 0.245
        save_crop(board, (x0, 0.685, x0 + 0.23, 0.88), f"feature-{key}-card.png", scale2=True)

  # Hero：竖版底部大界面
    print("Hero:")
    save_crop(vert, (0.04, 0.78, 0.98, 0.995), "hero-main.png", scale2=False)
    save_crop(vert, (0.04, 0.76, 0.98, 0.995), "hero-app.png", scale2=False)

    board.save(OUT / "design-board-full.png", "PNG", optimize=True)
    print(f"  design-board-full.png: {board.size}")
    print("Done →", OUT)


if __name__ == "__main__":
    main()
