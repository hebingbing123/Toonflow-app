# 宣传页截图（从设计稿裁剪）

素材来自两张 **设计拼板**（非当前 Flutter 产品 UI）：

| 源文件 | 说明 |
|--------|------|
| `ChatGPT_Image_2026_5_23__*.png` | 横版：5 张手机、桌面/Web、四大能力卡 |
| `1582682143637361566-*.png` | 竖版：功能三栏、Hero 大界面等 |

重新生成裁剪：

```bash
bash scripts/crop-website-assets.sh
```

## 页面引用

| 文件 | 用途 |
|------|------|
| `hero-app.png` | 首页 Hero 主视觉 |
| `desktop-studio.png` | 桌面端卡片 |
| `web-app.png` | Web 卡片 |
| `mobile-app.png` | 移动端卡片 |
| `feature-*.png` | 四大能力缩略图 |
| `design-board-full.png` | 底部设计总览 |
| `mobile-01` … `05` | 预览弹层轮播 |

设计稿更新后调整 `scripts/crop-website-assets.sh` 中的坐标即可。
