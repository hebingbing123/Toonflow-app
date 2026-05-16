## 产品深链（`/product/*`）规范

本文件定义 Flutter 产品壳层支持的 `linkPath` 路径（常用于通知中心 `settings.notification.*` 的 `payload.linkPath`），用于保证：

- **入口一致性**：面板被平台配置关闭时，深链不得绕过 gate
- **可演进**：新增深链时能同步到文档与 UI 处理逻辑

### 约定

- **格式**：`/product/<pane>`，参数用 query string。
- **gate 行为**：若目标面板被平台配置禁用，客户端应提示原因并跳转到 **平台配置** 面板。
- **稳定性**：深链仅用于产品壳层导航，不承诺跨版本永久兼容（若要兼容需在变更说明中保留别名路径）。
- **上下文恢复**：凡涉及 project / script / jobs scope，默认按 **UUID-first** 恢复；numeric 参数仅作 legacy fallback。
- **边界**：这里的 project/workspace scope 仅用于产品壳导航与上下文恢复，不单独决定 quota / billing attribution。

### 已支持路径

- **`/product/platform-config`**
  - **用途**：打开平台配置面板（永远可进）
  - **gate**：无

- **`/product/projects`**
  - **用途**：打开项目面板
  - **参数**：
    - `projectUuid`（可选，string）：首选项目 UUID（`app_project.id`）
    - `projectNumericId`（可选，int）：legacy 项目整型 ID 回退
  - **gate**：无

- **`/product/team-workspaces`**
  - **用途**：打开团队工作区面板
  - **gate**：无

- **`/product/jobs`**
  - **用途**：打开 jobs 面板并可预填 jobId
  - **参数**：
    - `jobId`（可选，string）：预填并触发查询
    - `projectUuid`（可选，string）：首选项目 UUID；用于同步产品壳项目上下文
    - `projectNumericId`（可选，int）：legacy 项目整型 ID 回退
    - `workspaceId`（可选，string）：同步工作区上下文
  - **gate**：`jobsPaneEnabled`
  - **说明**：若 query 未显式携带这些 scope 参数，客户端也可回退使用通知记录本身的 `projectId`（UUID）、`projectNumericId`（legacy numeric）/ `workspaceId` 与 payload 恢复上下文；恢复顺序仍以 UUID-first 为准。

- **`/product/platform-status`**
  - **用途**：打开平台状态面板（Health/Ready/SLI/Metrics）
  - **gate**：`platformStatusEnabled`

- **`/product/quality`**
  - **用途**：打开质量评审面板
  - **gate**：`qualityDashboardEnabled`

- **`/product/help`**
  - **用途**：打开帮助 Hub 面板
  - **gate**：`helpHubEnabled`

- **`/product/search`**
  - **用途**：打开全局搜索结果页（跨项目 / 剧本 / 资产）
  - **参数**：
    - `q`（必填，string）：搜索关键词，**2–200** 字符（与后端校验一致）
  - **gate**：无（未登录时结果页会提示先登录）
  - **说明**：支持路径形式 `.../product/search?q=关键词` 与常见 hash 形式 `...#/product/search?q=关键词`；App 启动时若初始 URI 命中也会自动打开结果页。

- **`/product/benchmark`**
  - **用途**：打开评测基线面板
  - **gate**：`benchmarkPaneEnabled`

- **`/product/workspace-activity`**
  - **用途**：打开工作区动态（执行动态）面板
  - **gate**：`workspaceActivityEnabled`
