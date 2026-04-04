# 数据库迁移：Supabase CLI 与 Rust（sqlx）

## 是不是 Flyway？

**不是 Flyway 这个产品**，但工作方式与 **Flyway / Liquibase** 同类：

- **版本化 SQL 文件**，按文件名里的时间戳顺序执行；
- **真源在仓库里**：本仓库为 `supabase/migrations/*.sql`；
- **日常开发/联调**以 **Supabase CLI** 为准：`supabase start`、`supabase db reset`、`supabase migration new …`。

## 为什么又有一个 Rust 入口？

在 **纯 Postgres**（例如 CI 里的临时库、或自管 PG 没有 Supabase 栈）上，没有 GoTrue/`auth` 等对象时，仍希望 **自动验证迁移能跑通**。因此提供：

1. **`backend/ci/pg_bootstrap_for_migrations.sql`** — 在裸库上创建最小的 `auth.users`、`authenticated` / `service_role` 角色和 `auth.uid()` 占位，满足现有 RLS / `GRANT … TO service_role` 语句。
2. **`toonflow-sqlx-migrate` 二进制** — 使用 **sqlx** 自带的迁移表 `_sqlx_migrations`（类似 Flyway 的 `flyway_schema_history`），对 **同一套** `supabase/migrations/` SQL 执行一遍。

### 与 Supabase 两套账本

| 环境 | 推荐方式 | 版本记录表 |
|------|----------|------------|
| Supabase 本地/云端 | `supabase db reset` / Dashboard 迁移 | Supabase 自有元数据 |
| 裸 Postgres / CI | `psql … bootstrap` + `cargo run --bin toonflow-sqlx-migrate` | `_sqlx_migrations` |

**不要在同一数据库上混用两种工具各跑一遍**（会重复执行同一 SQL）。任选其一作为该库的「唯一执行者」。CI 使用 **空库 + sqlx** 仅做语法/顺序冒烟。

## 命令示例（裸 Postgres）

```bash
export DATABASE_URL='postgresql://USER:PASS@HOST:5432/DB'
psql "$DATABASE_URL" -v ON_ERROR_STOP=1 -f backend/ci/pg_bootstrap_for_migrations.sql
cd backend && cargo run --bin toonflow-sqlx-migrate
```

可选：安装 **sqlx-cli** 后也可用 `sqlx migrate run --source ../supabase/migrations`（与二进制等价思路，见 [sqlx-cli](https://github.com/launchbadge/sqlx)）。
