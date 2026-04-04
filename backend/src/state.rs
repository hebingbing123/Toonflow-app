use sqlx::postgres::PgPoolOptions;
use sqlx::PgPool;

#[derive(Clone)]
pub struct AppState {
    pub pool: Option<PgPool>,
    pub jwt_secret: Option<Vec<u8>>,
}

impl AppState {
    pub async fn from_env() -> Result<Self, sqlx::Error> {
        let pool = match std::env::var("DATABASE_URL") {
            Ok(url) => {
                tracing::info!("connecting database");
                Some(
                    PgPoolOptions::new()
                        .max_connections(10)
                        .connect(&url)
                        .await?,
                )
            }
            Err(_) => {
                tracing::info!(
                    "DATABASE_URL not set; readiness will report database as not_configured"
                );
                None
            }
        };

        let jwt_secret = std::env::var("SUPABASE_JWT_SECRET")
            .ok()
            .filter(|s| !s.is_empty())
            .map(|s| s.into_bytes());

        if jwt_secret.is_none() {
            tracing::warn!("SUPABASE_JWT_SECRET not set; GET /api/v1/me returns 503");
        }

        Ok(Self { pool, jwt_secret })
    }
}
