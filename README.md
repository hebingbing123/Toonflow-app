<p>
  <a href="https://github.com/HBAI-Ltd/Toonflow-app">
    <img src="https://img.shields.io/badge/GitHub-181717?style=flat-square&logo=github&logoColor=white" alt="GitHub" />
  </a>
  &nbsp;|&nbsp;
  <a href="https://gitee.com/HBAI-Ltd/Toonflow-app">
    <img src="https://img.shields.io/badge/Gitee-C71D23?style=flat-square&logo=gitee&logoColor=white" alt="Gitee" />
  </a>
  &nbsp;|&nbsp;
  <a href="https://gitcode.com/HBAI-Ltd/Toonflow-app">
    <img src="./docs/atomgitLogo.svg" alt="Atomgit" style="height:20px"/>
  </a>
</p>

<p align="center">
  <strong>简体中文</strong> | 
  <a href="./docs/README.zhtw.md">繁體中文</a> | 
  <a href="./docs/README.en.md">English</a> | 
  <a href="./docs/README.th.md">ไทย</a> | 
  <a href="./docs/README.vi.md">Tiếng Việt</a> | 
  <a href="./docs/README.ja.md">日本語</a> | 
  <a href="./docs/README.ru.md">Русский</a>
</p>

<div align="center">

<img src="./docs/logo.png" alt="Toonflow Logo" height="120"/>

# Toonflow

  <p align="center">
    <b>
      AI短剧工厂
      <br />
      动动手指，小说秒变剧集！
      <br />
      AI剧本 × AI影像 × 极速生成 🔥
    </b>
  </p>
  <p align="center">
    <a href="https://github.com/HBAI-Ltd/Toonflow-app/stargazers">
      <img src="https://img.shields.io/github/stars/HBAI-Ltd/Toonflow-app?style=for-the-badge&logo=github" alt="Stars Badge" />
    </a>
    <a href="https://www.apache.org/licenses/LICENSE-2.0" target="_blank">
      <img src="https://img.shields.io/badge/License-Apache%202.0-blue.svg?style=for-the-badge" alt="Apache-2.0 License Badge" />
    </a>
    <a href="https://github.com/HBAI-Ltd/Toonflow-app/releases">
      <img alt="release" src="https://img.shields.io/github/v/release/HBAI-Ltd/Toonflow-app?style=for-the-badge" />
    </a>
  </p>
  
  > 🚀 **一站式短剧工程**：从文本到角色，从分镜到视频，0门槛全流程AI化，创作效率提升10倍+！
</div>



---

## Monorepo（Rust + Flutter）

| 目录 | 说明 |
|------|------|
| **`backend/`** | Rust（Axum）API，默认端口 **8666**；技能 Markdown 在 **`backend/data/skills/`** |
| **`frontend/`** | Flutter 桌面 + Web；`API_BASE_URL` + 可选 `SUPABASE_URL` / `SUPABASE_ANON_KEY`（见 `frontend/README.md`） |
| **`docs/plans/`** | 路线图快照：[`harness-rust-flutter.md`](docs/plans/harness-rust-flutter.md) |
| **`backend/src/openapi_spec/`** | OpenAPI：`openapi_base.yaml`（元数据、WebSocket、`components`）+ `openapi_paths_index.yaml`（路径索引）；合并结果由 Rust/utoipa 生成 |
| **`docs/websocket-events.md`** | WebSocket 稳定链接入口（正文见合并后的 OpenAPI **`/api/v1/ws`**） |
| **`supabase/`** | 本地 Postgres/Auth：`supabase start`；迁移在 `supabase/migrations/`（Flyway 式版本化 SQL，由 Supabase CLI 管理） |

> **重构完成**：旧 Electron + Node 栈已下线（`decommission-electron`）。当前主产品为 `backend/` + `frontend/` 新栈。  
> **自动化协作**：按 [`docs/plans/harness-rust-flutter.md`](docs/plans/harness-rust-flutter.md) 连续交付增量即可；Agent 行为约定见 **[`AGENTS.md`](AGENTS.md)**。
> **危险运维**：HTTP **`/api/v1/settings/danger/*`** 故意保持 **501**；如需按用户清理 SaaS 数据，使用 **`cargo run --bin toonflow-server --manifest-path backend/Cargo.toml -- ops clear-user-data --user-id <uuid> --dry-run`**，确认后再加 **`--execute --confirm clear-user-data:<uuid>`**。

### CI 与工程规范

- **本地重构门禁（与 CI 对齐，含 OpenAPI 解析）**：仓库根执行 **`yarn refactor:check`**（[`scripts/refactor-check.sh`](scripts/refactor-check.sh)）— `cargo run --bin export-openapi` 导出 YAML 校验 + `backend/` fmt/clippy/test + `frontend/` analyze/test。需本机已装 **Rust stable** 与 **Flutter**。
- **持续集成**：向 `main` / `master` 提 PR 或推送时运行 [`.github/workflows/ci.yml`](.github/workflows/ci.yml) — **`refactor-monorepo`** 任务执行与本地相同的 [`scripts/refactor-check.sh`](scripts/refactor-check.sh)（OpenAPI 解析 + `backend/` + `frontend/`）；**`supabase/migrations`**：`supabase db start` + `supabase db reset`；仓库根：旧栈 **`yarn lint`**（`tsc --noEmit`）。
- **迁移说明**：仅维护 [`supabase/migrations/`](supabase/migrations/)，详见 [`docs/migration/database-migrations.md`](docs/migration/database-migrations.md)。
- **工具链**：根目录 [`rust-toolchain.toml`](rust-toolchain.toml) 锁定 Rust stable + `rustfmt` / `clippy`。
- **依赖更新**：[`.github/dependabot.yml`](.github/dependabot.yml) 覆盖 Cargo、pub、GitHub Actions。

# 🌐 多语言支持

Toonflow 支持以下语言界面：

| 语言 | Language |
|------|----------|
| 简体中文 | Chinese (Simplified) |
| 繁體中文 | Chinese (Traditional) |
| English | English |
| ไทย | Thai |
| Tiếng Việt | Vietnamese |
| 日本語 | Japanese |
| Русский | Russian |

> 💡 更多语言适配中，欢迎贡献翻译！

---

# 🌟 主要功能

Toonflow v1.0.8 是面向短剧生产的 AI 工作台，围绕“策划 → 编剧 → 分镜 → 出片”构建完整闭环，并支持本地化、可编程、可持续迭代的生产流程。

- ✅ **无限画布生产工作台**  
  以类无限画布形式组织剧本、角色、分镜、素材与视频节点，支持自由编排、回溯与并行生产，不受线性步骤限制。
- ✅ **三层 Agent 协作体系**  
  决策层、执行层、监督层协同工作，覆盖任务拆解、内容生成、质量审阅与修订反馈，提升稳定性与成片一致性。
- ✅ **持久化 Agent 记忆**  
  基于本地 ONNX 向量检索的跨会话记忆系统，支持短期消息、长期摘要和语义召回，确保多轮创作连续性。
- ✅ **可编程供应商系统**  
  支持在设置中心直接编写供应商 TypeScript 逻辑并即时生效，无需改源码或重启，便于私有化和多模型接入。
- ✅ **章节事件图谱驱动改编**  
  自动提取原著章节事件并结构化存储，剧本改编按事件图谱精准调用上下文，减少长文本信息丢失。
- ✅ **Skill 文件化配置**  
  ScriptAgent 与 ProductionAgent 的核心提示词外化为 Markdown Skill 文件，支持在线编辑与快速调优。

---

# 📦 应用场景

- 网文/小说快速影视化改编
- 短剧团队流水线协作生产
- 多项目并行的 AI 内容工厂
- 私有化部署的企业级内容平台
- 低成本验证剧情与镜头方案
- 教学与研究场景下的 AIGC 创作实验

---

# 🔰 使用指南

## 🚀 v1.0.8 快速上手

1. 启动应用并登录（默认账号：`admin` / `admin123`）。
2. 在设置中心完成模型供应商配置（文本/图像/视频模型）。
3. 新建项目并导入原著，执行章节事件提取。
4. 进入 ScriptAgent 生成故事骨架、改编策略与结构化剧本。
5. 切换到 ProductionAgent，在无限画布中组织分镜、素材与视频节点。
6. 对分镜图进行节点化精调后回流工作台，完成视频拼接与导出。


## 📺 视频教程(待更新，老版本教程已无参考价值)

https://www.bilibili.com/video/BV1na6wB6Ea2
[![Toonflow 8 分钟快速上手 AI 视频](./docs/videoCover.png)](https://www.bilibili.com/video/BV1na6wB6Ea2)

**Toonflow 8 分钟快速上手 AI 视频**
👉 [点击观看](https://www.bilibili.com/video/BV1na6wB6Ea2/?share_source=copy_web&vd_source=5b718c25439a901a34c7bc0c1d35b38e)

📱 手机微信扫码观看

<img src="./docs/videoQR.png" alt="微信扫码观看" width="150"/>

---



# 🚀 安装

## 前置条件

在安装和使用本软件之前，请准备以下内容：

- ✅ 大语言模型 AI 服务接口地址
- ✅ Sora 或豆包视频服务接口地址
- ✅ Nano Banana Pro 图片生成模型服务接口

## 本机安装

### 1. 下载与安装

| 操作系统 | GitHub                                                  | Atomgit                                               | 夸克网盘下载                                    | 说明           |
| :------: | :----------------------------------------------------------- | :------------------------------------------------------------ | :---------------------------------------------- | :------------- |
| Windows  | [Release](https://github.com/HBAI-Ltd/Toonflow-app/releases) | [Release](https://gitcode.com/HBAI-Ltd/Toonflow-app/releases) | [夸克网盘](https://pan.quark.cn/s/94ef07509df0) | 官方发布安装包 |
|  Linux   | [Release](https://github.com/HBAI-Ltd/Toonflow-app/releases) | [Release](https://gitcode.com/HBAI-Ltd/Toonflow-app/releases) | [夸克网盘](https://pan.quark.cn/s/94ef07509df0) | 官方发布安装包 |
|  macOS   | [Release](https://github.com/HBAI-Ltd/Toonflow-app/releases) | [Release](https://gitcode.com/HBAI-Ltd/Toonflow-app/releases) | [夸克网盘](https://pan.quark.cn/s/94ef07509df0) | 官方发布安装包 |

> [!CAUTION]
> MacOS 系统请到 设置-隐私与安全性 配置安全性否则可能因证书问题无法正常打开
>
> 参考知乎文档：[https://www.zhihu.com/question/433389276](https://www.zhihu.com/question/433389276)

> 因 Gitee OS 环境限制及 Release 文件上传大小限制，暂不提供 Gitee Release 下载地址。

### 2. 启动服务

安装完成后，启动程序即可开始使用本服务。

> ⚠️ **首次登录**  
> 账号：`admin`  
> 密码：`admin123`

## Docker 与自建服务（新栈）

旧版 **`yarn docker:local`**、根目录 **`data/serve`**、固定端口 **10588** 等与 Electron 内嵌 Node 一体的方案 **已移除**。自建 API 请参考：

- **`backend/README.md`**：`cargo run --bin toonflow-server`、**`DATABASE_URL`**（Supabase Postgres）及可选存储/模型环境变量  
- **`supabase/`** 与 **`docs/migration/database-migrations.md`**  
- 契约：**合并 OpenAPI**（`GET /api/v1/openapi.yaml` 或 `export-openapi`）、**`docs/websocket-events.md`**

容器镜像若仍引用历史 Dockerfile，以路线图 **[`docs/plans/harness-rust-flutter.md`](docs/plans/harness-rust-flutter.md)** 为准逐步替换。

## 云端部署

旧版 **Node + PM2 + `data/serve/app.js`** 已下线。请在具备 **Postgres（推荐 Supabase）** 的环境中部署 **`backend/`**，客户端将 **`API_BASE_URL`** 指向该服务（见 **`frontend/README.md`**）。

---

# 🔧 开发流程指南

> [!CAUTION]
> 🚧 **PR 提交规范** 🚧
>
> ⛔ `master` 分支不接受任何 PR ｜ ✅ 请将 PR 提交到 `develop` 分支
>
> 欢迎开发者们共同参与 Toonflow 的共创。如有兴趣加入，请在交流群内联系主理人 ACT

## 🛠️ 技术栈（当前）

| 类别     | 技术 |
| -------- | ---- |
| 服务端   | Rust（Axum）、SQLx、Tokio |
| 客户端   | Flutter（桌面 / Web） |
| 数据库   | Supabase Postgres + Auth（RLS） |
| 实时     | WebSocket **`/api/v1/ws`** + Harness 协议 |
| 契约     | OpenAPI 3.1、**`docs/websocket-events.md`** |

## 开发环境准备

- **Rust**：见根目录 **`rust-toolchain.toml`**
- **Flutter**：与 **`frontend/pubspec.yaml`** 对齐的稳定版
- **Node / Yarn**：仅用于根目录 **`yarn lint`**（`tsc --noEmit`）与 **`yarn refactor:check`**

## 快速开始（开发者）

```bash
git clone https://github.com/HBAI-Ltd/Toonflow-app.git
cd Toonflow-app
yarn install
yarn refactor:check
```

- **后端**：`cd backend && cargo run --bin toonflow-server`（默认 **8666**，详见 **`backend/README.md`**）
- **前端**：**`frontend/README.md`**（`API_BASE_URL`、`SUPABASE_*` 等）

```bash
yarn lint             # 根目录 TypeScript 配置体检（可选）
```

## 前端开发

本仓库 **`frontend/`** 即为 Flutter 客户端源码。旧 **`Toonflow-web` → `data/web`** 的集成方式已废弃；历史仓库 **Toonflow-web** 仅供参考。

## 仓库结构（摘要）

```
backend/                 # Rust API、任务 worker、Harness
frontend/                # Flutter 应用
backend/data/skills/     # 打包技能 Markdown（运行时真源）
backend/src/openapi_spec/openapi_base.yaml
docs/plans/
supabase/migrations/
scripts/refactor-check.sh
package.json             # yarn lint / yarn refactor:check
```

---

# 🔗 相关仓库

| 仓库             | 说明                               | GitHub                                             | Gitee                                            |
| ---------------- | ---------------------------------- | -------------------------------------------------- | ------------------------------------------------ |
| **Toonflow-app** | 完整客户端（本仓库，推荐普通用户） | [GitHub](https://github.com/HBAI-Ltd/Toonflow-app) | [Gitee](https://gitee.com/HBAI-Ltd/Toonflow-app) |
| **Toonflow-web** | 旧版 Web 前端（历史参考）         | [GitHub](https://github.com/HBAI-Ltd/Toonflow-web) | [Gitee](https://gitee.com/HBAI-Ltd/Toonflow-web) |

> 💡 **提示**：当前主客户端在 **`frontend/`**（Flutter）。**Toonflow-web** 为旧栈参考仓库。

---

# 👨‍👩‍👧‍👦 微信交流群

拉群小助手:

<img src="./docs/QR.png" alt="Toonflow QR" height="400"/>

---

# 💌 联系我们

📧 邮箱：[ltlctools@outlook.com](mailto:ltlctools@outlook.com?subject=Toonflow咨询)

---

# 📜 许可证

Toonflow 基于 Apache-2.0 协议开源发布，并附有补充商业协议。

许可证详情：https://www.apache.org/licenses/LICENSE-2.0

## 补充协议

- 若将本软件以产品形式分发给 **2 个及以上独立第三方**使用，须取得 HBAI-Ltd **书面商业授权**。
- **≤ 5 个法人**联合运营内部使用，不对外提供服务的，视为内部使用，**无需授权**。
- 不得删除或修改 Toonflow 中的标识或版权信息。

## 永久免费场景

- ✅ 用 Toonflow 制作内容并获得平台分账
- ✅ 二次开发供自己团队内部使用
- ✅ ≤ 5 个法人联合运营内部使用
- ✅ 个人学习、研究、非商业用途

## 商业授权定价

| 阶段 | 年销售额 | 年费 |
|------|---------|------|
| 🌱 扶持期 | < ¥10 万 | **申请即可免费授权** |
| 🚀 初创期 | ¥10–50 万 | ¥5,000/年 |
| 📈 成长期 | ¥50–150 万 | ¥20,000/年 |
| 🏢 规模期 | ¥150–500 万 | ¥80,000/年 |
| 🌐 企业级 | > ¥500 万 | 面议 |

> **不追溯条款**：v1.0.8 发布前基于 AGPL-3.0 使用的用户，继续按 AGPL-3.0 执行，不受本协议变更约束。

完整协议详见 [LICENSE](./LICENSE) 文件。

---

# ⭐️ 星标历史

[![Star History Chart](https://api.star-history.com/svg?repos=HBAI-Ltd/Toonflow-app&type=timeline&legend=top-left)](https://www.star-history.com/#HBAI-Ltd/Toonflow-app&type=timeline&legend=top-left)

---

# 🙏 致谢

感谢以下开源项目为 Toonflow 提供支持（当前栈节选）：

- [Rust](https://www.rust-lang.org/) / [Tokio](https://tokio.rs/) / [Axum](https://github.com/tokio-rs/axum)
- [Flutter](https://flutter.dev/)
- [Supabase](https://supabase.com/)
- [SQLx](https://github.com/launchbadge/sqlx)
- [PostgreSQL](https://www.postgresql.org/)

感谢以下组织/单位/个人为 Toonflow 提供支持：

<table>
  <tr>
    <td>
      <img src="./docs/sponsored/sophnet.png" alt="算能云 Logo" width="48">
    </td>
    <td>
      <b>算能云</b> 提供算力赞助
      <a href="https://www.sophnet.com/">[官网]</a>
    </td>
  </tr>
</table>

完整的第三方依赖清单请查阅 `NOTICES.txt`

##### copyright © 淮北艾阿网络科技有限公司
