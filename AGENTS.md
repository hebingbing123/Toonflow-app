# 给 AI / Agent 的仓库约定

## 自动连续执行（不要等用户点「继续」）

- 以 [`docs/plans/harness-rust-flutter.md`](docs/plans/harness-rust-flutter.md) 为顺序，**完成一个可提交增量后，立刻做下一阶段**（同一轮对话里尽量多步：改代码 → 跑检查 → `git commit`），**不要**在文末问「要不要继续下一步」。
- 仅在高风险操作（如删库、`rm -rf`、改生产密钥）时暂停向人类确认。
- 默认 **小步多次 commit**，而不是停在「等你回复再继续」。

## 分叉自主决策（不要「请选择」、不要停）

- 出现 **多个方案**（架构选型、技术栈、实现路径、选项 1/2/3 等）时：**在仓库内自行选定其一并立即执行下一步**，**不要**向人类发起「请选择」或等待确认。
- 选定后 **用一两句话说明**：选了什么、主要理由（可维护性 / 契约一致性 / 与 `docs/plans/harness-rust-flutter.md` 对齐 / 风险等）。
- **每完成一轮决策点修复**（或 **一个主要变更阶段**）后：`git add` 相关文件并 **`git commit`**，提交说明建议包含：`AI decision: <方案摘要>，因为 <简要原因>。完成 <本阶段做了什么>。`
- 仍仅在 **高危操作**（删库、`rm -rf`、改生产密钥等）前暂停确认。

## 与 `master` 对照、体量与顺带修复

- 当前分支若 **已删除旧 Node/Electron 代码**，需要对照旧实现时：**以 `master`（或文档/parity 表）为参考**，用 `git show master:<path>` 等查看历史文件；**真源**仍是 [`docs/plans/harness-rust-flutter.md`](docs/plans/harness-rust-flutter.md) 与仓库内 OpenAPI/WS 文档。
- **单文件体量**：`backend/`、`frontend/` 中 **避免单文件过长**（建议 **≤800 行**；明显膨胀时 **拆模块/组件**），与路线图「竖切、可维护」一致。
- 对照 `master` 或 parity 时，若发现 **明确 bug、性能问题、明显不合理设计**，可在 **同一竖切/同一 PR 节奏内** 一并修复（避免无关大重构）。

## 重构栈门禁（自动跑，别让用户手动点）

凡改动 **`backend/`**（含 **`backend/src/openapi_spec/shell.rs`**、**`embedded/legacy_component_schemas.json`**（改后请跑 **`scripts/gen_legacy_utoipa_registry.py`**）、**`legacy_components/`**、**`openapi_spec/generated/`**、**`scripts/fixtures/openapi_stub_input.yaml`**（改后通常需跑 **`scripts/gen_openapi_utoipa_stubs.py`**））、**`frontend/`**、**`docs/websocket-events.md`**、**`.github/workflows/`**、**`supabase/migrations/`** 或 **`scripts/refactor-check.sh`**，在**宣布完成或 commit 之前**在仓库根执行：

```bash
yarn refactor:check
# 等价：bash scripts/refactor-check.sh
```

须 **合并后 OpenAPI 可解析**（`cargo run --bin export-openapi`，由 `scripts/refactor-check.sh` 执行）+ **`backend/`**：`cargo fmt --check`、`clippy -D warnings`、`test` + **`frontend/`**：`flutter pub get`、`analyze`、`test`。与 CI 任务 **`refactor-monorepo`**（[`.github/workflows/ci.yml`](.github/workflows/ci.yml)，内部即 **`scripts/refactor-check.sh`**）一致；不含 Supabase 起库与旧栈 **`yarn lint`**。失败则修到绿再提交；环境若缺 Rust/Flutter，说明缺什么即可。

## 为什么人类端还会觉得「每一步都要确认」？

1. **Cursor 产品设置**：终端/网络等操作可能弹出「Run / Allow」——在 Cursor **Settings** 里对当前工作区开启 **自动运行 / 减少审批**（具体名称随版本变化，如 *Auto-run*、*YOLO*、*Agent* 模式），可减少每次点确认。
2. **对话轮次**：一次「用户发消息」通常对应模型的一段输出；模型不能无限自己发下一条用户消息。若要一口气做完多阶段，可在**同一条用户指令**里写清范围（例如：「按路线图把 A、B、C 做完并分别 commit」），或依赖 **Agent 自动多步**（若你的 Cursor 版本支持且已打开自动执行）。

## 希望「尽量少点允许」时请在 Cursor 里做的事（人类操作一次即可）

界面文案随版本会变，按下面**意图**找对应开关即可：

1. 打开 **Settings**（macOS：`Cmd + ,`），搜索 **Agent** / **Auto-run** / **Terminal**。
2. 打开 **Agent 自动运行**（或「在 Agent 模式下自动执行终端命令」一类开关）。
3. 若提供 **命令允许列表（allowlist）**：为本仓库加入与门禁一致的命令，例如：
   - `bash scripts/refactor-check.sh`、`yarn refactor:check`
   - `cargo fmt`、`cargo clippy`、`cargo test`（工作目录在 `backend/` 时）
   - `flutter pub get`、`flutter analyze`、`flutter test`（工作目录在 `frontend/` 时）
   - `cargo run --bin export-openapi`（工作目录在 `backend/` 时）与 `ruby -ryaml`（解析导出的 YAML）
4. **不要**把高危操作放进允许列表（如 `rm -rf`、`git push --force`、直连生产数据库）；重构门禁脚本本身是只读检查 + 本地测试，风险可控。
5. 若仍频繁拦截：看 **Sandbox / Allowlist** 相关说明，或临时用 **Agent / Max** 模式（名称因版本而异），在**可信仓库**内使用。

完成以上设置后，**同一套** [`scripts/refactor-check.sh`](scripts/refactor-check.sh) 在本地与 Agent 终端里才能接近「改完即跑、少打断」。

## 与本地 `.cursor/rules` 的关系

仓库根 `.cursor/` 可能被 `.gitignore` 忽略；**本文件是进 Git 的约定**，便于任何克隆本仓库的 Agent 行为一致。
