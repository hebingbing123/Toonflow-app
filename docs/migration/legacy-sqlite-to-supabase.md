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

1. **盘点与契约**：按业务域分组表（用户/项目/剧本/分镜/素材/任务），与 Supabase Auth 的 `user_id`（UUID）对齐方式写清（旧 `o_user.id` 为整型，需 **`legacy_user_map`**）。
2. **PG 目标模型**：`app_project` / `app_script` 与 RLS 已由迁移提供；更多实体（分镜/素材等）后续迁移迭代追加。
3. **ETL 工具（仓库内原型）**：在应用 `supabase/migrations` 中的 `legacy_staging.snapshot` 表之后，可用 Rust CLI 将旧库 **按行快照为 JSONB**（不做业务域映射）：
   ```bash
   cd backend
   supabase db reset   # 或确保已执行含 legacy_staging 的迁移
   SQLITE_PATH=/path/to/db2.sqlite DATABASE_URL=postgresql://... \
     cargo run --bin toonflow-legacy-import --release
   ```
   可选：导入前清空 staging：`LEGACY_IMPORT_TRUNCATE=1`。表名白名单见 `src/bin/legacy_import.rs`（与 `initDB` 一致）。**Blob** 列以 `base64:` 前缀写入字符串。

4. **归一化表与提升（本仓库已提供）**  
   迁移 `20260404120000_app_domain_and_promote.sql` 创建：
   - `public.legacy_user_map`：旧 `o_user.id`（int）→ `auth.users.id`（uuid），用于写入 `app_project.owner_user_id`。
   - `public.app_project` / `public.app_script`：与旧 `o_project` / `o_script` 核心字段对齐；**RLS** 仅允许 `owner_user_id = auth.uid()` 的行通过 API 访问。
   - 函数 `public.promote_legacy_from_staging()`（**SECURITY DEFINER**，仅 **`service_role`** 可执行）：从 `legacy_staging.snapshot` 幂等 upsert 到上述表。  
   典型顺序：
   ```sql
   -- 1) 为每个 Supabase 登录用户建立映射（示例：旧 admin id=1）
   INSERT INTO public.legacy_user_map (legacy_user_id, supabase_user_id)
   VALUES (1, '00000000-0000-0000-0000-000000000000'::uuid);  -- 换成真实 auth.users.id

   -- 2) 在 Dashboard SQL 或以 service_role 连接执行
   SELECT * FROM public.promote_legacy_from_staging();
   ```
   未配置 `legacy_user_map` 时，项目仍会写入 **`owner_user_id` 为空**，客户端在 RLS 下**不可见**，直至补映射并再次执行 promote（`owner_user_id` 用 `COALESCE` 合并策略更新）。
5. **校验**：行数对比、抽样业务校验、只读并行期；回滚预案见路线图 §11.9。
6. **下线双写**：确认 Flutter 客户端全量切 Rust API 后再停旧写 SQLite。

## 与当前仓库的衔接

- 新栈 schema 起点：`supabase/migrations/`（如 `app_user_profile`）。
- 本文件不替代 PRD；具体列级映射在实现 ETL 的 PR 中维护。
