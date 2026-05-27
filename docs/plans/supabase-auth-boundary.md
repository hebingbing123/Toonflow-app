# Supabase 客户端边界（HEALTH-013）

## 约定

- **Flutter 产品壳**仅使用 Supabase SDK 做 **Auth**（登录、注册、session、`access_token`）。
- **业务数据**（项目、剧本、分镜、通知内容等）经 **Rust API**（`API_BASE_URL` + Bearer）与 [`frontend/lib/rust_api/`](../../frontend/lib/rust_api/) 访问。
- **禁止**在 `frontend/lib/` 使用 `Supabase.instance.client.from('app_*')` 或等价 PostgREST 直连业务表。

## 数据库防护

- 用户面向表 RLS：[`supabase/migrations/20260624120000_app_user_facing_rls.sql`](../../supabase/migrations/20260624120000_app_user_facing_rls.sql)
- 审计 / 运维表：[`supabase/migrations/20260624130000_app_backend_only_rls.sql`](../../supabase/migrations/20260624130000_app_backend_only_rls.sql)

## 本地检查

```bash
rg "\.from\('app_" frontend/lib && exit 1 || exit 0
```
