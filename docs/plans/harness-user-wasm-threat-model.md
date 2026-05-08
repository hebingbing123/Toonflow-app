# Harness：用户上传 WASM — 威胁模型

> 与 [`roadmap-backend-harness.md`](./roadmap-backend-harness.md) **WP-C** 对齐；实现以代码与安全评审为准。当前仓库：**`wasm.probe`** 为嵌入探针模块；REST 有 **`validate`**（不落库）与 **`persist`/`list`/`revoke`**；WS `harness.tool.invoke` 已接入 **`wasm.user.probe`**（按 `wasm_id` 执行 owner 下 active 行）。

## 信任边界

- **不可信**：用户或合作方提供的任意 WASM 字节流。
- **可信**：API 进程、存储签名校验、配额/审计服务、运维 kill-switch。

## 主要威胁

| 威胁 | 说明 | 缓解方向（设计级） | 可验证约束（代码 / 测试） |
|------|------|---------------------|---------------------------|
| **任意代码** | WASM 在解释器内仍可消耗 CPU/内存、触发宿主 bug | 解释器选用与版本固定；**燃料/指令计数**、**内存上限**、**超时**；独立低权 OS 用户/ cgroup（若未来迁出进程） | **`invoke_user_probe`**：`wasmi` fuel（`HARNESS_USER_WASM_FUEL_LIMIT`）+ 单测 `user_probe_fuel_exhaustion_*`；invoke 超时（`HARNESS_USER_WASM_INVOKE_TIMEOUT_MS`，WS 层）；`wasm_runtime::tests::user_probe_runs_probe_export` |
| **侧信道 / 定时** | 通过时长推断其他租户数据 | 禁止 **`wasm.probe`** 级的网络/存储；用户工具默认无私有 API；噪声或调度隔离属进阶项 | 用户 WASM 路径无宿主 IO 导入；侧信道缓解仍以架构隔离为 **`next`**（本表不宣称已解决） |
| **资源耗尽** | 大体积模块、实例风暴 | 上传 **大小上限**、**每用户/每 workspace 配额**、并发 invoke **排队/拒绝** | `validate_user_wasm_upload` + `HARNESS_USER_WASM_MAX_BYTES`：`wasm_runtime::tests::user_wasm_validation_rejects_oversize`；契约 `harness_validate_user_wasm_bad_request_oversize`；持久化配额 `HARNESS_USER_WASM_MAX_STORED_PER_USER` + list cap（见 PG/契约） |
| **供应链** | 恶意或篡改的二进制 | **内容寻址存储**、**发布签名**、可 **吊销** 列表；仅允许注册已知 ABI | 行内 **`wasm_sha256`** + object 一致性校验；`DELETE` 软删除 + `GET` 过滤 `revoked_at`；审计 `persist`/`revoke` |
| **逃逸与宿主接口** | 非法导入宿主函数 | **最小化导入表**；禁止 `wasi` 网络/文件除非显式白名单评审 | 当前用户 probe **仅**导出 `probe`，Linker **无** WASI 导入；扩展 ABI 须单独评审 |
| **审计与合规** | 无法追溯谁跑了什么 | **上传/注册/调用** 写审计日志；与 **`request_id` / `user_id` / `workspace_id`** 关联 | `app_harness_user_wasm_audit` + `harness.user_wasm.audit` 日志；PG 合约 / 定向测试见 `user_wasm_audit_db` |

## 运维开关

- 内建 **`wasm.probe`**：环境变量 **`HARNESS_WASM_PROBE_DISABLED`** 为 **`1` / `true` / `yes` / `on`** 时拒绝执行（见 `backend/README.md`）。
- **投递体量上限（WP‑C 薄切片）**：校验辅助函数读取 **`HARNESS_USER_WASM_MAX_BYTES`**（默认 512KiB；`0` 或未解析回退默认），与 **`validate_user_wasm_upload`** / **`POST /api/v1/harness/user-wasm/validate`** 配套（仅校验体积与模块解析；不写入存储）。持久化：**`POST /api/v1/harness/user-wasm`** 复用同一校验并按 **`HARNESS_USER_WASM_MAX_STORED_PER_USER`**（默认 **64** 行）写入 **`app_harness_user_wasm`**；列表 **`GET`** 上限 **`HARNESS_USER_WASM_LIST_CAP`**（默认 **100**）。
- **吊销（WP‑C 软删除）**：**`DELETE /api/v1/harness/user-wasm/{id}`** 设置 **`app_harness_user_wasm.revoked_at`**；行保留用于审计，但 **`GET /api/v1/harness/user-wasm`** 会按 **`revoked_at IS NULL`** 过滤并且 **吊销行不计入配额**。
- **WS 执行（最小闭环）**：`harness.tool.invoke` 工具 **`wasm.user.probe`** 仅允许 owner 的 active 行（`revoked_at IS NULL`），并以 **`HARNESS_USER_WASM_FUEL_LIMIT`**（默认 50,000,000）启用 wasmi fuel 保护；燃料耗尽返回 `error.occurred` + `code=wasm_failed`。本轮新增执行超时上限 **`HARNESS_USER_WASM_INVOKE_TIMEOUT_MS`**（默认 3000ms），超时返回 `code=wasm_timeout`。
- **运维开关（用户 WASM）**：环境变量 **`HARNESS_USER_WASM_DISABLED`** 为 `1/true/yes/on` 时拒绝 `wasm.user.probe`。后续若引入更多用户 WASM 工具，应统一挂接同一 kill-switch（位点：`backend/src/harness/wasm_runtime.rs`）。
- **结构化审计（本轮）**：`validate` / `persist` / `revoke` / `invoke`（success/fail）均写 `harness.user_wasm.audit`，字段包含 `event`、`user_id`、`workspace_id`（WS 可得时）、`wasm_id`、`wasm_sha256`、`request_id`、`result`、`error_code`；以上四类事件均做最小持久化到 `app_harness_user_wasm_audit`（失败不阻断主流程）。入库前会对 `request_id` / `error_code` 做 trim，空白值归一为 `NULL`，避免跨路径字段语义漂移。
- **对象存储最小可落地（本轮）**：`HARNESS_USER_WASM_STORAGE_BACKEND=object_store` 时启用独立 object_store 适配层；默认仍是 **`pg_inline`**。object_store 模式下支持两条路径：  
  1) **S3 兼容真实后端**（MinIO/AWS S3）：当 `HARNESS_USER_WASM_OBJECT_STORE_ENDPOINT`、`..._BUCKET`、`..._REGION`、`..._ACCESS_KEY_ID`、`..._SECRET_ACCESS_KEY` 就绪时，走签名请求写读删对象；可选 `..._SESSION_TOKEN`、`..._PREFIX`。  
  2) **配置半缺失保护**：当 object_store 关键配置仅部分存在时，判定为 misconfigured 并触发回退语义（不再隐式切到 in-memory mock），避免跨环境行为漂移。  
  `persist` 优先写 object_store 并记录 `storage_key`，若写失败则**降级为 PG inline**（`storage_key=NULL`）保持 API 成功语义；`invoke` 优先按 `storage_key` 读取 object_store，若读取失败 / miss / 对象 SHA256 与行内 `wasm_sha256` 不一致，则回退 inline bytes；`revoke` 之后对 object 进行 best-effort 删除（失败仅告警，不破坏 revoke 幂等）。测试可用 `HARNESS_USER_WASM_OBJECT_STORE_FAIL=put|get|delete|all` 注入失败验证策略。
  - **验证状态（更新）**：已补齐定向测试覆盖 `persist -> get_active(invoke 读取路径) -> revoke(best-effort delete)` 主链路，以及 `put/get/delete` 故障语义；真实后端 E2E 用例为 `#[ignore]`，在配置 MinIO/S3 环境变量后执行。
- **可观测/告警信号（本轮补齐）**：新增统一结构化事件 `event=harness_user_wasm_signal`，固定键包含 `signal_name`、`user_id`、`workspace_id`、`request_id`、`wasm_id`、`storage_key`、`backend`、`outcome`、`error_code`；关键失败路径已接入 `object_store_put_fail` / `object_store_get_fail` / `object_store_delete_fail` / `invoke_wasm_failed` / `invoke_wasm_timeout`，可直接按 `signal_name+error_code` 聚合阈值实现最小告警。`object_store_get_fail` 在 WS `wasm.user.probe` 路径可透传 `request_id/workspace_id/wasm_id`，用于把对象存储回退与同次 invoke 审计事件做一跳关联。
- **错误分类收敛（本轮）**：对象存储 IO 异常统一收敛到 `database_error`，配置半缺失保留 `object_store_misconfigured` 特化码；对象缺失与 SHA 不一致保留 `object_store_miss` / `object_store_sha_mismatch` 以区分数据面异常与基础设施异常。

## 统一失败信号告警模板（可直接复制）

以下模板围绕 `event=harness_user_wasm_signal`，按 `signal_name,error_code` 聚合；查询语法可按日志平台（Loki / Datadog / CloudWatch Logs Insights）做轻微适配。

### 查询模板 1：5 分钟窗口聚合 TopN（通用）

```text
event="harness_user_wasm_signal"
| stats count() as signal_count by signal_name, error_code
| sort signal_count desc
| limit 20
```

### 查询模板 2：按 request_id 去重（降噪版）

```text
event="harness_user_wasm_signal"
| stats dc(request_id) as uniq_requests by signal_name, error_code
| sort uniq_requests desc
| limit 20
```

### 默认阈值建议（起步值，可按环境调优）

| 信号 | 建议窗口 | 建议阈值 | 备注 |
|------|----------|----------|------|
| `invoke_wasm_timeout` + `wasm_timeout` | 5 分钟 | `count >= 3` 或 `uniq_requests >= 3` | 优先级高，通常代表执行超时或资源配额偏紧 |
| `invoke_wasm_failed` + `wasm_failed` | 5 分钟 | `count >= 5` 或 `uniq_requests >= 3` | 先排除单个损坏样本，再看是否批量回归 |
| `object_store_put_fail` + `object_store_put_failed` | 10 分钟 | `count >= 2` 或 `uniq_requests >= 2` | 存储写入失败对后续路径影响较大，应尽早告警 |

### 降噪建议（避免误报）

- 以 `uniq_requests`（去重 request_id）优先于原始 count，降低同一请求重试造成的噪声。
- 增加维度过滤：仅统计 `outcome="fail"` 且 `backend in ("object_store","wasm_runtime")`。
- 引入连续窗口策略：例如“连续 2 个窗口超阈值”再触发高优先级告警。
- 对已知演练/压测窗口添加临时 mute 标签，避免影响值班判断。

## 已决议项（当前分支；变更须安全评审 + 更新本表）

- **WASI 子集**：**默认不允许**。用户上传 WASM 仅走 **`probe` ABI**（无 WASI 导入）。若未来开放 WASI，必须 **显式白名单**（逐宿主函数评审）、独立特性开关与威胁模型增量；在此之前代码路径保持 **零文件/网络** 宿主绑定。
- **LLM tool 与长期记忆**：用户 WASM **工具输出** 与其他 harness 工具同等对待——**不自动写入**任何跨会话「模型长期记忆」存储；若产品接入持久记忆，必须 **按 workspace / 用户可见性过滤** 且 **默认不落敏感工具载荷**，见 Agent 产品条款与安全评审（实现落地属 **`next`**，与 WP‑E 协调）。
- **日志与审计保留**：运维层 **保留周期 / 冷热分层** 仍 **`next`**（依赖部署与合规策略）；应用侧已保证 **结构化字段** 与 DB 审计表可导出。

## 开放问题（仍待跨职能结论）

- 中央日志与 **`app_harness_user_wasm_audit`** 的 **正式保留周期**、归档与访问控制（与 SIEM 策略对齐）。
