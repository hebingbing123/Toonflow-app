# 数据库迁移：统一使用 `supabase/migrations`

## 单一真源

所有 **PostgreSQL schema 变更**只维护在：

**`supabase/migrations/*.sql`**

命名与 Flyway 类似：`YYYYMMDDHHMMSS_description.sql`，由 **Supabase CLI** 按顺序应用并记录版本（本地/远程各自一套元数据，但**文件只有这一处**）。

**Rust / sqlx** 只连库、跑查询；**不在应用里再跑一套迁移**，避免和 Supabase 账本冲突。

## 本地开发（可以，且推荐）

1. 安装 [Supabase CLI](https://supabase.com/docs/guides/cli) 与 Docker。
2. 仓库根目录：
   ```bash
   supabase start          # 本地全栈（含 Postgres、Auth 等），首次会拉镜像
   # 或仅数据库：
   supabase db start
   ```
3. 应用迁移（开发中改完 SQL 后常用）：
   ```bash
   supabase db reset       # 按当前 migrations 重建本地库（会清数据）
   ```
4. 连接串：执行 `supabase status`，把 **DB URL** 配到 Rust 的 `DATABASE_URL`。

新建迁移：

```bash
supabase migration new my_change
# 编辑生成的 supabase/migrations/<timestamp>_my_change.sql
```

## CI

PR/推送流水线里用同一套 CLI：`supabase db start` → `supabase db reset --yes --no-seed`，确保 `supabase/migrations` 在**官方本地镜像**上能完整跑通（见根目录 `.github/workflows/ci.yml`）。

## 云端 Supabase

在托管项目上应用迁移：按官方流程 **`supabase link`** 后 **`supabase db push`**（或 Dashboard），仍只使用仓库里的 `supabase/migrations/*.sql`。
