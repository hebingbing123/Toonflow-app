//! Apply `supabase/migrations/*.sql` using **sqlx**'s migration ledger (`_sqlx_migrations`).
//! Flyway-style ordering uses the numeric filename prefix (same files as Supabase CLI).
//!
//! - **Supabase local/cloud**: keep using `supabase db reset` / `supabase migration up` as the primary
//!   workflow; Supabase records versions in its own schema.
//! - **Bare Postgres / CI**: run `psql … -f backend/ci/pg_bootstrap_for_migrations.sql`, then
//!   `DATABASE_URL=… cargo run --bin toonflow-sqlx-migrate`.

use sqlx::postgres::PgPoolOptions;

#[tokio::main]
async fn main() -> anyhow::Result<()> {
    let _ = dotenvy::dotenv();
    let url = std::env::var("DATABASE_URL")
        .map_err(|_| anyhow::anyhow!("DATABASE_URL is required (postgresql://…)"))?;
    let pool = PgPoolOptions::new()
        .max_connections(1)
        .connect(&url)
        .await?;
    sqlx::migrate!("../supabase/migrations").run(&pool).await?;
    Ok(())
}
