# 旧栈 SQLite → Supabase Postgres 迁移说明

## 角色划分

| 形态 | 存储 | 说明 |
|------|------|------|
| **新栈（Rust + Flutter）** | **Supabase PostgreSQL** | 唯一主库；开发与生产见 `docs/plans/harness-rust-flutter.md` §4.1 |
| **旧栈（Electron + Node）** | **SQLite**（`db2.sqlite`，Knex + better-sqlite3） | 仅迁移**源**；见 `src/utils/db.ts`、`src/lib/initDB.ts` |

## 源库表清单（Knex `initDB`）

以下表名来自 `src/lib/initDB.ts`，迁移时需映射到 PG schema（建议 `public` 下新表名或带 `legacy_` 前缀 staging，再归一到目标模型）：

- `o_user`, `o_project`, `o_artStyle`, `o_agentDeploy`, `o_setting`, `o_tasks`, `o_prompt`
- `o_novel`, `o_event`, `o_eventChapter`, `o_outline`, `o_outlineNovel`, `o_script`
- `o_assets`, `o_image`, `o_storyboard`, `o_agentWorkData`, `o_video`, `o_videoTrack`, `o_vendorConfig`
- `o_imageFlow`, `o_assets2Storyboard`, `o_scriptAssets`, `o_skillList`, `o_skillAttribution`

## 推荐阶段（标准交付节奏）

1. **盘点与契约**：按业务域分组表（用户/项目/剧本/分镜/素材/任务），与 Supabase Auth 的 `user_id`（UUID）对齐方式写清（旧 `o_user.id` 为整型，需映射策略）。
2. **PG 目标模型**：在 `supabase/migrations/` 中实现目标表 + RLS/索引；避免在 PG 中长期保留 SQLite 的整型主键语义，除非过渡期双键。
3. **ETL 工具**：可选路径 — 一次性脚本（Node 读 SQLite + `pg` 写）、或 Rust `sqlx` 读 sqlite（需加依赖）批量 `INSERT`；大 blob/路径字段与 `data/oss` 文件一并校验。
4. **校验**：行数对比、抽样业务校验、只读并行期；回滚预案见路线图 §11.9。
5. **下线双写**：确认 Flutter 客户端全量切 Rust API 后再停旧写 SQLite。

## 与当前仓库的衔接

- 新栈 schema 起点：`supabase/migrations/`（如 `app_user_profile`）。
- 本文件不替代 PRD；具体列级映射在实现 ETL 的 PR 中维护。
