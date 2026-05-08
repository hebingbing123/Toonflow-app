# Harness：用户上传 WASM — 威胁模型（草稿）

> 与 [`roadmap-backend-harness.md`](./roadmap-backend-harness.md) **WP-C** 对齐；实现以代码与安全评审为准。当前仓库：**`wasm.probe`** 为嵌入探针模块；REST 另有 **`validate`**（不落库）与 **`persist`/`list`**：**通过校验的用户 WASM** 写入 **`app_harness_user_wasm`**（仍为 **stub**，未接 WS `invoke`/吊销）。

## 信任边界

- **不可信**：用户或合作方提供的任意 WASM 字节流。
- **可信**：API 进程、存储签名校验、配额/审计服务、运维 kill-switch。

## 主要威胁

| 威胁 | 说明 | 缓解方向（设计级） |
|------|------|---------------------|
| **任意代码** | WASM 在解释器内仍可消耗 CPU/内存、触发宿主 bug | 解释器选用与版本固定；**燃料/指令计数**、**内存上限**、**超时**；独立低权 OS 用户/ cgroup（若未来迁出进程） |
| **侧信道 / 定时** | 通过时长推断其他租户数据 | 禁止 **`wasm.probe`** 级的网络/存储；用户工具默认无私有 API；噪声或调度隔离属进阶项 |
| **资源耗尽** | 大体积模块、实例风暴 | 上传 **大小上限**、**每用户/每 workspace 配额**、并发 invoke **排队/拒绝** |
| **供应链** | 恶意或篡改的二进制 | **内容寻址存储**、**发布签名**、可 **吊销** 列表；仅允许注册已知 ABI |
| **逃逸与宿主接口** | 非法导入宿主函数 | **最小化导入表**；禁止 `wasi` 网络/文件除非显式白名单评审 |
| **审计与合规** | 无法追溯谁跑了什么 | **上传/注册/调用** 写审计日志；与 **`request_id` / `user_id` / `workspace_id`** 关联 |

## 运维开关

- 内建 **`wasm.probe`**：环境变量 **`HARNESS_WASM_PROBE_DISABLED`** 为 **`1` / `true` / `yes` / `on`** 时拒绝执行（见 `backend/README.md`）。
- **投递体量上限（WP‑C 薄切片）**：校验辅助函数读取 **`HARNESS_USER_WASM_MAX_BYTES`**（默认 512KiB；`0` 或未解析回退默认），与 **`validate_user_wasm_upload`** / **`POST /api/v1/harness/user-wasm/validate`** 配套（仅校验体积与模块解析；不写入存储）。**Stub 持久化**：**`POST /api/v1/harness/user-wasm`** 复用同一校验并按 **`HARNESS_USER_WASM_MAX_STORED_PER_USER`**（默认 **64** 行）写入 **`app_harness_user_wasm`**；列表 **`GET`** 上限 **`HARNESS_USER_WASM_LIST_CAP`**（默认 **100**）。对象存储 offload、调用审计仍为 **`next`**。
- **吊销（WP‑C 软删除）**：**`DELETE /api/v1/harness/user-wasm/{id}`** 设置 **`app_harness_user_wasm.revoked_at`**；行保留用于审计，但 **`GET /api/v1/harness/user-wasm`** 会按 **`revoked_at IS NULL`** 过滤并且 **吊销行不计入配额**。
- 未来用户 WASM 注册路径须复用或扩展 **同一类** 全局 kill-switch（待 WP-C 实装）。

## 开放问题

- 是否允许 **WASI** 子集（只读预挂载目录 vs 完全无 IO）。
- 与 **LLM tool** 持久化记忆的交互（工具输出是否进入长期记忆须防泄漏）。
