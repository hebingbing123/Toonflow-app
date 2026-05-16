# Backend 领域层需求审查（风险导向）与实施计划

本文档基于对 `backend/src` **目录结构、SQL 分布、关键竖切抽样阅读** 得出结论；**不是**逐行审计全部 `.rs` 文件（约 200+ 个源文件），而是回答：**哪些地方最可能「改一处要动好几处」、哪里值得抽领域逻辑、建议什么顺序做**。

**总判断**：当前 **竖切 + 共享模块（如 `production_flow`）+ `billing` 内聚规则** 已经承担了大量「领域层」工作；**不必**为全仓 DDD 重写。**优先**在下列 **热点** 做 **小步、可测** 的抽取即可。

---

## 1. 已经做得不错的部分（可视为「已有领域内核」）

| 区域 | 说明 |
|------|------|
| **`billing/ingest/subscription_state.rs`** | `resolve_subscription_state`、终态回滚守卫、时间戳/置信度规则 — **纯函数为主**，已是典型的「订阅状态」领域逻辑（只是放在 `ingest` 目录下，而非名叫 `domain`）。 |
| **`billing/provider_rules/`** | 各 Provider 的归一化与测试 — **适配器 + 规则表**，与 Webhook 编排分离得合理。 |
| **`production_flow.rs`** | 文件头已写明供 **HTTP 与 Harness 共用**；`resolve_owned_production_scope`、`load_owned_production_flow_json` 等 — **正确的共享「领域+持久化」边界**（仍含 SQL，属应用/基础设施混合，但避免了 REST 与工具各写一套查询）。 |
| **`metering/quota.rs`** | 配额优先级（override → tier 默认）+ `#[cfg(test)]` — **已有向可测性靠拢**；tier 倍率仍可再纯函数化（见 §3）。 |

这些区域 **不需要** 为了「像 DDD」而搬家；若要统一命名，将来最多只做 **目录/模块别名**，不改行为。

---

## 2. 高风险热点（最值得考虑「领域层」或「共享应用服务」）

下面按 **「重复面 × 规则复杂度 × 变更频率」** 综合排序。

### 2.1 Harness 工具与 REST 的 **并行实现**（最需要警惕「改两处」）

- **`harness/invoke/domain_script.rs`**、**`domain_production.rs`**：工具侧含 **鉴权/归属**（如 `require_owned_script_scope`）与 **读业务数据** 的 SQL。
- **叙事/制作/资产** 各竖切的 **`handlers.rs`** 与 **`projects/routes.rs`**：同类「项目归属、剧本 scope、资产 scope」在多处出现。

**风险**：产品改一条归属规则或 ID 解析规则时，若只改 HTTP 或只改 Harness，会出现 **契约一致但行为不一致**（`pg_contract_tests` 未必每组合都覆盖）。

**建议方向**（不是全仓 `domain/`）：抽 **窄接口的「归属解析」模块**（例如 `scope::resolve_script_in_project(owner, project_numeric, script_numeric) -> Result<ScriptScope, DomainError>`），由 **HTTP handler 与 Harness invoke 共用**，SQL 仍集中在 1～2 个 `impl` 文件里。

### 2.2 **制作流程保存**（`production/workbench/flow.rs`）

- `post_save_flow_data` 内对 `storyboard` 数组顺序有 **UPDATE `sb_index`** 等逻辑，与 **JSON flow** 强耦合。

**风险**：规则变复杂时（例如校验、部分更新），handler 会膨胀，难单测。

**建议**：把「从 `body.data` 推出待更新的 storyboard 顺序与合法性」拆成 **纯函数**（输入 `Value` / 结构化 DTO，输出 `Vec<(numeric_id, index)>` 或错误），handler 只负责事务与执行 SQL。

### 2.3 **大文件 handler / workbench**（规则与 IO 混在一起）

以下文件 **行数高** 且 **含大量 SQL 与分支**（基于 `wc -l` 与抽样）：

- `narrative/events/handlers.rs`、`narrative/novels/handlers.rs`、`narrative/storyboards/handlers.rs`
- `assets/workbench_write.rs`、`production/workbench/storyboard_ops.rs`、`production/workbench/storyboard.rs`
- `jobs/handlers.rs`、`projects/routes.rs`、`settings/vendors/handlers.rs`

**风险**：不是「没有分层」，而是 **单文件承担过多用例**，后续 **同一业务规则**（如列表筛选语义、软删除级联）容易在复制粘贴中分叉。

**建议**：按 **用例** 拆文件（竖切内再分子模块）+ 对 **重复出现的筛选/排序/分页** 抽 **Query 对象或 builder**；仅当同一规则出现 **≥3 次** 再考虑独立 `domain` 类型。

### 2.4 **计量与套餐**（`metering/quota.rs`）

- `plan_tier` 与 **日配额倍率** 写在 `match` 里，与 **环境变量**、**DB 列** 交织。

**风险**：改套餐名或倍率时，易漏改注释或 **`GET /api/v1/me`** 相关展示逻辑。

**建议**：抽 **纯函数** `fn tier_daily_cap_multiplier(tier: &str) -> ...` + **单测**（无需引入完整 DDD）。

### 2.5 **任务队列与 Worker**（`jobs/`）

- `jobs/handlers.rs`、`jobs/enqueue.rs`、`jobs/worker/*`：**幂等、状态机、cancel 轮询** 与 HTTP 入口混在不同文件，但 **边界相对清晰**。

**风险**：中等；若以后加 **复杂状态迁移**（不仅是 `queued→running→…`），适合把 **允许迁移** 抽成 **纯函数** 或小型 `enum` 状态机。

**建议**：**现阶段**以 **契约测试 + 现有 worker 结构** 为主；**不优先**建独立 `domain` 包，除非出现多处复制同一迁移条件。

---

## 3. 优先级矩阵（建议执行顺序）

| 优先级 | 动作 | 预期收益 | 成本 |
|--------|------|----------|------|
| **P0** | **归属与 scope**：整理 `require_owned_script_scope` / `resolve_owned_production_scope` / 项目路由里的重复查询，收敛到 **单一「scope」模块 + 双方调用** | 显著降低 **HTTP vs Harness** 行为漂移 | 中（需仔细跑 `pg_contract_tests` + Harness 探针） |
| **P1** | **`flow.rs` 保存路径**：把 storyboard 排序与校验从 handler 抽到 **纯函数** + 单测 | 改 UI/流程 JSON 时不炸库 | 低～中 |
| **P2** | **`metering/quota`**：tier 倍率与环境默认值 **纯函数化** | 改套餐不踩坑 | 低 |
| **P3** | **最大 handler 文件**：按用例拆分 + 提取重复查询（不必命名成 DDD） | 单人维护时导航更快 | 持续进行 |
| **P4** | **billing**：已较内聚；仅当 **新订阅规则** 继续变复杂时，考虑把 `subscription_state` **改名为更醒目的模块**（如 `billing::subscription`） | 可读性 | 极低 |

---

## 4. 分阶段计划（可与 [`ddd-full-migration-c.md`](./ddd-full-migration-c.md) 对照）

### 阶段 A（1～2 周，建议最先做）

1. **盘点重复 SQL**：搜索 `FROM app_script` / `app_project` / `owner_user_id` 在 **Harness `invoke`** 与 **`projects`/`narrative`/`production`** 中的出现位置，列一张 **对照表**（谁与谁等价）。
2. **实现 P0**：新建顶层 **`backend/src/scope/`**（见 §4.1 **模块落点**），把 **「用户拥有下的 project/script 解析」** 收敛；**HTTP 与 Harness 改为调用同一入口**。
3. **门禁**：`yarn refactor:check`；有 DB 时跑 **`pg_contract_tests`**；Flutter/Harness 探针按你现有习惯回归。

### 阶段 B（并行或紧随）

1. **P1**：`production/workbench/flow.rs` 提取纯函数 + 测试。
2. **P2**：`metering/quota` tier 逻辑纯函数化。

### 阶段 C（按需）

- 对 **P3 列表** 中大文件：**只拆文件 + 抽查询**，不强行引入 `domain`/`application` 目录，直到 **重复规则** 真的成为痛点。

### 刻意不做（除非业务倒逼）

- **全仓** `domain/` + `application/` + `infrastructure/` **大迁移**（见 [`ddd-full-migration-c.md`](./ddd-full-migration-c.md)）。

### 4.1 实施方案（可执行）

下列内容把 §4 **拆成可提交的步骤**；**不必**一次做完，**每一小步合并后主干保持可发布/可开发**。

#### 通用门禁（每一批合并前）

在仓库根执行（与 [`AGENTS.md`](../../AGENTS.md) 一致）：

```bash
yarn refactor:check
```

涉及行为或 SQL 时：在 **可连 Postgres** 的环境补跑与改动相关的 **`app::pg_contract_tests`**（或至少覆盖该路径的 `#[ignore]` 用例）。

#### 阶段 A：P0 归属 / scope 收敛（建议 2～4 个 PR）

**模块落点（定稿建议）**：使用 **顶层 `backend/src/scope/`**（`main.rs` 增加 `mod scope;`），**不要**放在 `projects/scope.rs`。

- **原因**：归属解析被 **Harness、production、narrative、scripting** 等多竖切共用，不是 `projects` 专属；放 `projects/` 易误导依赖方向（其它模块「为了 scope 依赖 projects」）。
- **调用路径**：`crate::scope::...`；代码量尚小时可用单文件 `scope.rs`，再拆 `scope/mod.rs` 与子模块。
- **与 `production_flow.rs` 并列**：二者均为 **跨入口共享**，顶层并列更清晰。

| 步骤 | 做什么 | 产出物 |
|------|--------|--------|
| **A0** | 从 §5 的 `rg` 结果整理 **重复 SQL 对照表**（单独 issue 或本文档末尾自增「附录：对照表」） | 表列：路径、查询意图、是否与 `domain_script` / `production_flow` 等价 |
| **A1** | 新建 **`backend/src/scope/mod.rs`**（或先 `scope.rs`），实现 **单条**「用户拥有下的 project+script 解析」API，**逻辑从** `harness/invoke/domain_script.rs::require_owned_script_scope` **迁入或薄封装** | Harness **仅调用**该模块；行为与迁前一致 |
| **A2** | 将 **REST 侧** 与 A1 等价的查询改为调用同一 API（可按竖切分批：`production_flow` 相关、`scripting`、`narrative`…） | 删除或缩窄重复 `sqlx` 块；契约测试绿 |
| **A3** | 对 **`resolve_owned_production_scope`** 与 A1 的关系做 **文档注释**（何时用哪一个、是否将来合并） | 避免下一任再复制第三种查询 |

**验收（阶段 A 完成）**：同一归属语义在 **Harness 与 HTTP** 仅 **一处** 实现（允许薄包装）；相关 `pg_contract_tests` / 你常用的 Flutter 探针通过。

#### 阶段 B：P1 + P2（各 1 个 PR 或合并为 1 个）

| 步骤 | 做什么 | 产出物 |
|------|--------|--------|
| **B1** | `production/workbench/flow.rs`：`post_save_flow_data` 内 storyboard 顺序/校验 → **`pub(crate)` 纯函数** + `#[cfg(test)]` | handler 变薄；单测覆盖边界情况 |
| **B2** | `metering/quota.rs`：`plan_tier` 倍率与环境默认 → **纯函数**（如 `tier_daily_cap(...)`），`effective_daily_job_quota_for_user` 只负责 IO | 改 tier 数字只动一处 + 单测 |

#### 阶段 C：P3（持续、小 PR）

- 每次只拆 **1～2 个** §2.3 中的大文件（按用例分子模块），**不**引入全仓 `domain/`。
- **验收**：`refactor:check` 绿；该竖切相关契约仍绿。

#### 分支建议

- 长周期可在 **`refactor/scope-convergence`**（名称自定）上做多 PR，**每 PR 可独立 review**，避免单次上万行 diff。

---

## 5. 你如何自己发现「改一处要动好几处」

在仓库根执行（示例）：

```bash
rg -n "FROM app_script|owner_user_id|numeric_id" backend/src --glob '!**/pg_contract_tests/**' --glob '!**/contract_smoke_tests/**'
```

若同一 **业务含义** 的查询在 **`harness/invoke`** 与 **`narrative`/`production`/`projects`** 各有一份，即 **P0 候选**。

---

## 6. 模块覆盖范围（未逐文件审查清单）

**目的**：避免把本计划理解成「已对 `backend` 所有源码做完整 code review」。下表与 **`main.rs` 顶层模块**（及与之并列的 **`error`**）对齐；**`app/`** 内另列常见子树。

**图例**

- **逐文件审查**：否 = 未通读该模块下每个 `.rs`；**是** = 仅适用于极少数单文件（如 `production_flow.rs`）或明确点名的文件。
- **本计划中的位置**：文档 § 或「未点名」= 默认 **未展开**。
- **默认判断**：在未再审计的前提下，**领域逻辑抽取的相对优先级**（高/中/低）；**不等于**「该模块写得差」。

### 6.1 与 `main.rs` 对齐的顶层模块

| 模块 | 逐文件审查 | 本计划中的位置 | 默认判断 |
|------|------------|------------------|----------|
| **`app/`** | 否（`router`/`handlers`/子树未逐文件） | 入口与路由；§2、§4 泛指 | **中**：聚合全仓竖切；热点在子模块而非 `app` 根 |
| **`assets/`** | 否 | §2.3 点名部分大文件 | **高**：与 workbench、生成任务交叉多 |
| **`auth/`** | 否 | 未点名 | **低～中**：鉴权与 claims；业务规则少 |
| **`billing/`** | 否（抽样 `ingest`、`provider_rules`） | §1、§2 隐含、§3 P4 | **中**：核心规则已集中在 `subscription_state` 等；增量改规则时优先在此层 |
| **`error/`** | 否 | 未点名 | **低**：错误映射与 HTTP 形状 |
| **`harness/`** | 否（抽样 `invoke/`、`ws/`） | §2.1 | **高**：与 REST **并行路径**，P0 相关 |
| **`http_kit/`** | 否 | 未点名 | **低**：通用中间件/JSON 等 |
| **`jobs/`** | 否（抽样 handler/worker） | §2.5、§3 | **中**：状态迁移复杂化时再抽纯函数 |
| **`llm/`** | 否 | 未点名 | **低～中**：Provider 适配；领域规则多在 prompt/调用方 |
| **`manuals/`** | 否 | 未点名 | **中**：导演/视觉手册等业务 CRUD；未做文件级评估 |
| **`metering/`** | 否（抽样 `quota.rs`） | §1、§2.4、§3 P2 | **中**：tier 纯函数化见计划 |
| **`narrative/`** | 否（抽样 events/novels/storyboards） | §2.1、§2.3 | **高**：handler 体量大、与 scope 查询重叠 |
| **`production/`** | 否（抽样 `workbench/`） | §2.2、§2.3 | **高**：flow 保存与制作链路 |
| **`production_flow.rs`** | **单文件重点读过** | §1 | **中**：已是共享内核；继续 **收敛重复** 而非重写 |
| **`projects/`** | 否（抽样 `routes.rs`） | §2.1、§2.3、P0 | **高**：项目 scope 与路由面大 |
| **`prompting/`** | 否 | 未点名 | **中**：提示词/技能列表；是否抽领域视产品迭代 |
| **`scripting/`** | 否（抽样 scripts/agent/asset_extract） | §2.1 与 Harness 重叠 | **高**：剧本与工具侧 **重复 SQL** 风险 |
| **`settings/`** | 否（抽样 `vendors/handlers`） | §2.3 | **中**：供应商/凭证/危险操作 |
| **`state/`** | 否 | 未点名 | **低**：`AppState` 与环境装配 |
| **`vendor/`** | 否 | 未点名 | **低～中**：第三方视频/目录等适配 |

### 6.2 `app/` 内常见子树（补充）

| 路径 | 说明 | 默认判断 |
|------|------|----------|
| **`app/pg_contract_tests/`**、**`app/contract_smoke_tests/`** | 契约与烟雾测试 | **不适用**「领域层需求」；用于 **验收** 重构而非业务分层 |
| **`app/ops.rs`** 等 | CLI / 运维入口 | **低～中**：与产品领域规则弱相关 |

### 6.3 其他

| 路径 | 说明 |
|------|------|
| **`backend/src/bin/`**（如 `sqlite_import`） | 独立二进制；未纳入本计划 |
| **未列出的深层文件** | 凡未在 §2 点名者，均视为 **未抽样**；若以后某路径成为痛点，按 §5 自扫或补一节「补充审查」 |

---

## 7. 文档维护

- **P0 / A1**：已新增顶层 **`backend/src/scope/mod.rs`**（`owned_script_scope`）；**Harness** `require_owned_script_scope` 委托该模块。
- **P0 / A2（部分）**：**`production_flow::resolve_owned_production_scope`**、**`invoke_get_script_content`** 已先 scope 再读剧本列；**`scope::ScopeError::into_api_error`** 供 HTTP 侧复用。
- **P0 / A2（制作 workbench 一批）**：**`production/workbench/`** 下 `meta`（生成 prompt / get_generate_data）、`track`（add/delete track、delete/select video）、`video`（generate 探针）、`assets`（batch 出图）、`storyboard`（add / batch_add）、`storyboard_ops`（batch_generate_image）已用 **`owned_script_scope`** 替代原 **COUNT + JOIN** 或改为 **`WHERE script_id = …`（UUID）** 更新/删除。
- **P0 / A2（UUID 项目路径）**：新增 **`scope::owned_script_in_project`**（`app_project.id` + `script_numeric_id`）；已用于 **`scripting/scripts/crud`**（GET/PATCH/DELETE 剧本）、**`narrative/storyboards/handlers`**（按剧本列分镜、创建分镜）、**`assets/crud/links`**（脚本–资产解析）、**`assets/crud/list`**（`script_numeric_id` 过滤前校验）。
- **分镜 numeric（项目 UUID）**：**`scope::owned_storyboard_in_project`** + **`fetch_storyboard_row`**；已用于 **`narrative/storyboards/handlers`** 的 get/patch/delete by numeric。
- **继续**：**`scripting/asset_extract/extract_job`** 单剧本校验与 **`mark_script_failed`** 已用 **`owned_script_in_project`**；**`production/workbench/storyboard`** 的 **next/base numeric** 改为 **按 `script_id` 聚合**（修正跨项目取 MAX 问题）；**`post_get_storyboard_data`（project+script numeric）** 已先 **`owned_script_scope`** 再列分镜。
- **仍可按需收敛**：**`export_poll`**（跨项目多 numeric）、仅 **storyboardId** 无 project 的旧接口、Harness **`get_planData`** 列表查询等。
- 实施 P0/P1 后，可在本文档 **§2** 对应条目标记 **「已收敛到 `<路径>`」**，避免以后重复审查。

若你希望下一步 **自动产出「重复 SQL 对照表」**（脚本 + 输出清单），可以单独开任务做 **rg + 人工标注** 半自动报告。
