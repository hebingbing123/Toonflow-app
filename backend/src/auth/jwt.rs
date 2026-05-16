//! Supabase 风格 HS256 JWT 解码（`sub`、`exp`、`aud: authenticated`）。

use jsonwebtoken::{decode, Algorithm, DecodingKey, Validation};
use serde::Deserialize;

/// JWT 令牌声明（Claims）。
///
/// Supabase 风格的 JWT 结构，包含用户标识和过期时间。
#[derive(Debug, Deserialize)]
pub struct Claims {
    /// 用户 UUID（主题）。
    pub sub: String,
    /// 过期时间戳（Unix 秒）。
    #[allow(dead_code)]
    pub exp: i64,
    /// 用户邮箱（可选）。
    pub email: Option<String>,
}

pub fn verify_supabase_user_jwt(
    token: &str,
    secret: &[u8],
) -> Result<Claims, jsonwebtoken::errors::Error> {
    let mut validation = Validation::new(Algorithm::HS256);
    validation.validate_exp = true;
    validation.set_audience(&["authenticated"]);

    let key = DecodingKey::from_secret(secret);
    let data = decode::<Claims>(token, &key, &validation)?;
    Ok(data.claims)
}
