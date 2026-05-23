# 宣传页截图（从设计稿裁剪）

素材来自 `website/assets/source/` 两张设计拼板（**非**当前 Flutter 产品 UI）：

| 源文件 | 说明 |
|--------|------|
| `ChatGPT Image 2026年5月23日 12_39_47.png` | 横版高清（1309×1201）：手机五屏、桌面/Web、底部四能力卡 |
| `1582682143637361566.jpg` | 竖版（572×1024）：功能三栏、Hero 大界面 |

旧版 `design-board.png` / `design-vertical.png` 仅作脚本回退。

重新生成全部裁剪：

```bash
bash scripts/crop-website-assets.sh
```

坐标在 `scripts/crop-website-assets.py`（百分比框，换源图尺寸时一般不用改像素）。

## 页面引用

| 文件 | 用途 |
|------|------|
| `features-trio.png` / `@2x` | 核心能力横幅 |
| `feature-*.png` / `@2x` | 四大能力卡片（竖版顶部三栏 + 私有化） |
| `feature-*-card.png` / `@2x` | 横版底部四宫格（备用，更清晰图标卡） |
| `hero-main.png` | 首页 Hero 主视觉 |
| `desktop-studio.png` | 桌面端卡片 |
| `web-app.png` | Web 卡片 |
| `mobile-app.png` | 移动端卡片 |
| `design-board-full.png` | 底部设计总览（高清横版） |
| `mobile-01` … `05` | 预览弹层轮播 |
