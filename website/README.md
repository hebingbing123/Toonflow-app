# OpenFlow 宣传网站

基于品牌视觉（深色科技风、`#7C97FF` / `#34C8F0`、Space Grotesk + Inter）的单页介绍站。

**与后端同启**：`openflow-server` 在仓库存在 `website/index.html` 时，会在 **与 API 相同端口**（默认 `8666`）的根路径 `/` 提供本目录静态文件，无需单独起 Python 或其它 HTTP 服务。

## 本地预览（推荐）

在仓库根配置好 `backend/.env`（`DATABASE_URL` 等）后：

```bash
cd backend
cargo run --bin openflow-server
```

浏览器打开：

- 宣传页：**http://127.0.0.1:8666/**
- API 文档：**http://127.0.0.1:8666/api/v1/docs**
- 健康检查：**http://127.0.0.1:8666/health**

## 环境变量（后端）

| 变量 | 说明 |
|------|------|
| `OPENFLOW_MARKETING_SITE` | 设为 `0` / `false` / `off` / `no` 可关闭根路径静态站 |
| `OPENFLOW_MARKETING_SITE_DIR` | 自定义目录（默认 `../website`，相对 `backend/`） |

## GitHub Pages（可选）

若需与 API 分离的纯静态托管，仍可使用 [`.github/workflows/website-pages.yml`](../.github/workflows/website-pages.yml) 发布到 `gh-pages` 分支。

## 配置外链与 Web 应用

编辑 [`js/config.js`](./js/config.js)：

| 字段 | 说明 |
|------|------|
| `appUrl` | Flutter Web / 应用登录地址；留空时「登录」滚动到「快速上手」 |
| `docsUrl` / `docsEnUrl` | 中文 / 英文文档 |
| `releasesUrl` | GitHub Releases |
| `demoVideoUrl` | 演示视频（可选） |

同域部署 API 时，文档链接可改为相对路径或 `http://127.0.0.1:8666/api/v1/docs`。

## 目录

```
website/
  index.html
  css/styles.css
  js/config.js
  js/i18n.js
  js/main.js
  assets/
```

语言偏好：`localStorage` 键 `openflow-site-locale`（右上角 **EN / 中文**）。
