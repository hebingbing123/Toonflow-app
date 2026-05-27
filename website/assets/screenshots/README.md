# 宣传页截图（从设计稿裁剪）

## 源文件

| 源文件 | 说明 |
|--------|------|
| `Gemini_Generated_Image_5vxlmk5vxlmk5vxl.png` | **主源**（768×1376）：顶部三能力、四宫格图标、底部 Hero 大界面 |
| `ChatGP*.png` / `design-board.png` | 横版（约 1309×1201）：手机五屏、桌面/Web 全平台区 |
| `design-vertical.png` | 仅脚本回退 |

重新生成：

```bash
bash scripts/crop-website-assets.sh
```

坐标在 `scripts/crop-website-assets.py`（百分比框；换源图尺寸时一般只需微调比例）。

## 页面引用

| 文件 | 用途 |
|------|------|
| `hero-main.png` / `@2x` | 首页 Hero 主视觉（Gemini 底部大界面） |
| `feature-*-card.png` / `@2x` | 核心能力配图（仅裁三栏内 UI 窗口 + 私有化图标卡，不含营销大标题） |
| `features-trio.png` / `@2x` | 预览弹层三能力横条 |
| `desktop-studio.png` 等 | 全平台介绍（横版 board） |
| `design-gemini-full.png` | Gemini 源图归档 |
| `design-board-full.png` | 横版 board 归档 |

`feature-*.png`（旧竖版 572px 裁切）已停用，勿再引用。
