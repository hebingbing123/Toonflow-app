#!/usr/bin/env python3
"""从 website/assets/source/ 设计拼板裁剪宣传页素材（百分比坐标，适配高清源图）。"""
from __future__ import annotations

from pathlib import Path

from PIL import Image

ROOT = Path(__file__).resolve().parents[1]
SRC = ROOT / "website/assets/source"
OUT = ROOT / "website/assets/screenshots"

# 竖版高清拼板（核心能力 + Hero）
GEMINI = SRC / "Gemini_Generated_Image_5vxlmk5vxlmk5vxl.png"
GEMINI_FALLBACK = SRC / "design-vertical.png"

# 横版拼板（全平台 / 手机五屏）
BOARD = SRC / "ChatGPT Image 2026年5月23日 12_39_47.png"
BOARD_ALT = SRC / "ChatGP12_39_47.png"
BOARD_FALLBACK = SRC / "design-board.png"


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


def save_crop(
    im: Image.Image,
    pct: tuple[float, float, float, float],
    name: str,
    *,
    scale2: bool = True,
    min_width: int | None = None,
) -> None:
    crop = im.crop(box_from_pct(im, *pct)).convert("RGB")
    if min_width is not None and crop.width < min_width:
        ratio = min_width / crop.width
        crop = crop.resize(
            (min_width, max(1, int(crop.height * ratio))),
            Image.Resampling.LANCZOS,
        )
    path = OUT / name
    crop.save(path, "PNG", optimize=True)
    if scale2:
        c2 = crop.resize((crop.width * 2, crop.height * 2), Image.Resampling.LANCZOS)
        c2.save(OUT / name.replace(".png", "@2x.png"), "PNG", optimize=True)
    print(f"  {name}: {crop.size}" + (" +@2x" if scale2 else ""))


def crop_gemini_hero_and_features(gemini: Image.Image) -> None:
    """Gemini 竖版：顶部三能力栏 + 四宫格图标 + 底部 Hero 大界面。"""
    print("Gemini / hero & features:")
    # 顶部介绍：底部分镜工作区大截图
    save_crop(gemini, (0.04, 0.76, 0.96, 0.99), "hero-main.png", scale2=True)
    save_crop(gemini, (0.04, 0.74, 0.96, 0.99), "hero-app.png", scale2=True)

    # 核心能力：顶部三栏（含界面预览，比旧竖版 572px 更清晰）
    trio_pct = (0.02, 0.06, 0.98, 0.34)
    save_crop(gemini, trio_pct, "features-trio.png", scale2=True)

    top_cols = [
        ("script", (0.02, 0.06, 0.33, 0.34)),
        ("storyboard", (0.34, 0.06, 0.66, 0.34)),
        ("collab", (0.67, 0.06, 0.98, 0.34)),
    ]
    for key, pct in top_cols:
        save_crop(gemini, pct, f"feature-{key}-card.png", scale2=True)

    # 私有化：中部四宫格图标卡（第四格）
    save_crop(gemini, (0.73, 0.54, 0.98, 0.68), "feature-private-card.png", scale2=True)

    gemini.save(OUT / "design-gemini-full.png", "PNG", optimize=True)
    print(f"  design-gemini-full.png: {gemini.size}")


def crop_board_platforms(board: Image.Image) -> None:
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
    board.save(OUT / "design-board-full.png", "PNG", optimize=True)
    print(f"  design-board-full.png: {board.size}")


def main() -> None:
    OUT.mkdir(parents=True, exist_ok=True)
    gemini_path = pick(GEMINI, GEMINI_FALLBACK)
    gemini = Image.open(gemini_path)
    print(f"Gemini: {gemini_path.name} {gemini.size}")
    crop_gemini_hero_and_features(gemini)

    board_path = pick(BOARD, BOARD_ALT, BOARD_FALLBACK)
    board = Image.open(board_path)
    print(f"Board: {board_path.name} {board.size}")
    crop_board_platforms(board)
    print("Done →", OUT)


if __name__ == "__main__":
    main()
