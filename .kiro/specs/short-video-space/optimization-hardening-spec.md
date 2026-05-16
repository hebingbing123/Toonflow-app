# short-video-space 优化补强 Spec（Post-MVP）

## 背景

当前 `short-video-space` 主任务线已完成（含 K1-K5、I1-I4），但在高并发一致性、时间线持久化安全、导出门禁真实化、发布平台能力表达上仍存在可优化空间。  
本 spec 用于下一轮“稳定性 + 真实能力”补强，不推翻现有功能，只做增强。

## 优先级与目标

### P0（必须）

1. 解决同项目并发刷新导致的旧数据覆盖新数据问题。  
2. 让时间线重排持久化具备冲突检测（避免静默丢更新）。  
3. 单镜头时长对齐改成最小字段写回，避免回写陈旧 prompt。  
4. 导出质量门禁从“占位提示”升级为可配置 `off/warn/block` 策略。

### P1（高价值）

1. 发布能力矩阵增加 `delivery_mode`（sandbox/live/manual_bridge）可见性。  
2. 发布流程从“任意一步失败即整块 unavailable”改为分片容错。  
3. 统一 `assembly / compare / export-check` 快照版本，降低跨面板口径漂移。

### P2（体验/维护）

1. 错误提示结构化（状态码 + 后端 message/code + 下一步动作）。  
2. Rust API wrapper 强化 typed request/response，减少契约漂移。  
3. 受限多轨面板补“查看更多/分页”或“按脚本筛选”。

### 维护说明：`section_*.dart` 与 `flutter analyze`

- **`ShortVideoSpaceSection` 拆成 `part` + `extension on _ShortVideoSpaceSectionState`**：各 part 里调用 `setState` 在语义上合法（扩展的接收者就是 `State` 子类实例），但分析器会把 `this` 当成扩展类型，触发 **`invalid_use_of_protected_member`**。当前在对应 **`part` 文件顶部**使用 **`// ignore_for_file: invalid_use_of_protected_member`**（及少数文件的 **`library_private_types_in_public_api`**）压制误报。
- **不推荐**用 `mixin X on _ShortVideoSpaceSectionStateBase` 拆到多个 part **且** 仍让 part 之间互相调用 `_foo()`：在 `on` 仅为 `StateBase` 时，**静态上**看不到定义在**其他 mixin** 上的私有方法（例如 `section_project` 调 `section_production` 的 `_loadProjectOverview`），会报 **undefined_method**。要彻底去掉 ignore，需要要么 **合并为单类**，要么在 **Base 上声明一整套 abstract 转发 API**（成本高）。

---

## 任务清单

### O1. Overview 并发代际保护（P0）

- **范围**：`frontend/lib/short_video_space/section.dart`
- **实现**：
  - 为 `_loadProjectOverview()` 引入 request epoch（或 generation token）。
  - 仅应用“当前最新请求”的结果，旧请求返回后直接丢弃。
  - 对 `_refreshPublishSlice()` 复用相同机制。
- **验收**：
  - 连续触发 10 次刷新，最终 UI 只保留最后一次结果。
  - 不再出现“操作成功后 UI 回退到旧值”。

### O2. 时间线持久化冲突检测（P0）

- **范围**：`frontend/lib/short_video_space/section.dart`、`backend/src/production/workbench/flow/*`
- **实现**：
  - `save-flow-data` 增加版本字段（`flow_version` / `updated_at` / etag 等等）。
  - 前端保存重排时携带版本；后端版本不一致返回冲突错误。
  - 冲突时前端提示“存在他端修改，请刷新后重试”。
- **验收**：
  - 双端同时编辑同一脚本顺序时，不会静默覆盖。
  - 用户能明确看到冲突原因和恢复路径。

### O3. 时长对齐最小字段写回（P0）

- **范围**：`frontend/lib/rust_api/production/storyboard/*`、`backend/src/production/workbench/storyboard/mutate/*`
- **实现**：
  - 新增仅更新 duration 的接口（或 patch payload）。
  - 前端 `runAlignDuration()` 改为调用该接口，不再“先读 prompt 再整条写回”。
- **验收**：
  - 时长对齐不会覆盖 prompt/video_desc 等其他字段。
  - 并发修改 prompt 时不再出现回滚。

### O4. 导出质量门禁策略化（P0）

- **范围**：`backend/src/projects/routes/handlers/detail/short_video_export_check.rs`、`frontend/lib/short_video_space/support.dart`
- **实现**：
  - 项目级门禁策略：`off | warn | block`。
  - 在 `block` 模式下命中阈值时阻止导出入队。
  - 返回结构化阻断原因 + 可跳转修复入口。
- **验收**：
  - `block` 模式命中规则会明确阻断并提示修复动作。
  - `warn` 模式仅告警不拦截。

### O5. 发布能力真实度标识（P1）

- **范围**：`backend/src/publish/*`、`frontend/lib/short_video_space/*`
- **实现**：
  - attempts / jobs 增加 `delivery_mode` 与 evidence（request_id/manual_step_id）。
  - UI 区分“沙箱成功”与“真实发布成功”。
- **验收**：
  - 任意发布记录都能看出是 sandbox 还是真实投递。
  - 平台矩阵与状态文案不再混淆“接通”与“演练”。

### O6. 发布分片容错与可观测错误（P1）

- **范围**：`frontend/lib/short_video_space/section.dart`
- **实现**：
  - `_capturePublishSlice()` 改为按 matrix/drafts/jobs/perf 分片容错。
  - 错误文案展示 `status + backend message + 建议动作`。
- **验收**：
  - 单一接口失败不导致整块 publish 面板 unavailable。
  - 用户可定位是哪一段失败并继续执行可用动作。

### O7. 统一快照版本（P1）

- **范围**：`backend/src/projects/routes/handlers/detail/*`、`frontend/lib/short_video_space/*`
- **实现**：
  - `assembly/compare/export-check` 响应增加 `snapshot_version`（或 `as_of`）。
  - 前端在版本不一致时展示“数据时间点不一致，请刷新后再决策”。
- **验收**：
  - 三面板可感知同一快照时间点。
  - 不一致时有明显提醒，避免误判。

### O8. Rust API 合约加固（P2）

- **范围**：`frontend/lib/rust_api/**`
- **实现**：
  - 关键写接口成功判定改为 `2xx`。
  - `storyboard-media-op` 增加 typed request model，减少 magic string。
  - 为关键 endpoint 加 contract drift smoke tests。
- **验收**：
  - 后端返回 `204` 等合法 2xx 时前端不误报失败。
  - 关键 payload 变更时能在测试阶段暴露。

---

## 非目标

- 不引入电影级 NLE 能力（需求 8.2 边界保持不变）。  
- 不在本轮处理与 short-video-space 无关的全仓重构。

## 里程碑建议

- **Milestone A（P0）**：O1-O4  
- **Milestone B（P1）**：O5-O7  
- **Milestone C（P2）**：O8 + 体验打磨

